# Docker on macOS (mac-work host).
#
# macOS has no Linux kernel, so the Docker *daemon* can't run natively — it
# needs a Linux VM. Colima provides that: a lightweight VM (Apple's
# Virtualization.framework on Apple Silicon) running the Docker engine, driven
# entirely from the CLI. This is the Nix-native alternative to Docker Desktop
# (no Homebrew, no proprietary licence).
#
# This is a home-manager module (not nix-darwin / NixOS): there's no
# virtualisation.docker on darwin — that option is Linux-kernel-native and has
# no darwin equivalent — and the docker CLI belongs in the same profile as
# docker-credential-gcloud (already installed via google-cloud-sdk in
# shell/cli.nix). Co-locating them satisfies gcloud's requirement that `docker`
# and `docker-credential-gcloud` share a PATH, so the Google Artifact Registry
# credential helper (us-east4-docker.pkg.dev in ~/.docker/config.json) works for
# pulls/pushes.
#
# The launchd agent is home-manager's `services.colima` (added 2025-10-15),
# which replaced a hand-rolled `launchd.agents.colima` here. What the upstream
# module is worth adopting for is the DECLARATIVE half: it renders colima.yaml
# from Nix (so VM sizing stops being imperative state set by `colima start
# --cpu N`) and gives the agent a hermetic PATH — colima genuinely shells out to
# perl for shasum on image download and to ssh for port forwarding, which the
# hand-rolled agent resolved from /usr/bin.
#
# Its SUPERVISION half is overridden below, because it does not survive either
# failure mode measured on this machine. See startColima.
{ ... }:
{
  flake.modules.homeManager.dockerMac =
    { config, lib, pkgs, ... }:
    let
      colima = lib.getExe config.services.colima.package;

      # `colima start` alone cannot keep docker up under launchd. Two failure
      # modes, both MEASURED here 2026-08-19:
      #
      # 1. THE WEDGE. lima's VM process outlives its host agent (a crash, or
      #    sleep), and every later start dies on
      #
      #      Instance "colima" has configuration errors:
      #        vz driver is running but host agent is not
      #
      #    Only `colima stop --force` clears that split state. Nothing in either
      #    supervision policy does it, so docker was down from Aug 18 to Aug 19
      #    across ~6000 failed starts until it was cleared by hand.
      #
      # 2. THE UNSUPERVISED VM. `colima start` on an already-running instance
      #    logs "already running, ignoring" and exits 0 IMMEDIATELY — it does not
      #    stay in the foreground. launchd is then supervising nothing while the
      #    VM runs orphaned at PPID 1. Seen the moment a darwin-rebuild replaced
      #    this agent: the outgoing supervisor was SIGTERMed, the incoming one
      #    bailed out on "already running", and `launchctl list` showed the agent
      #    with no PID and the VM still up. Docker kept working, so the lost
      #    keep-running property was invisible until the next crash.
      #
      # Upstream's KeepAlive.SuccessfulExit = true (restart on clean exit, give
      # up on a failed one) is the inverse of ours and fixes neither: the wedge
      # exits nonzero and is never retried (quiet, but down until the next login,
      # which re-wedges), and the already-running case exits 0 and is restarted
      # into an exit-0 spin loop at launchd's 10s default. Hence mkForce on both
      # ProgramArguments and KeepAlive.
      #
      # This wrapper instead makes the agent always OWN the VM it supervises:
      #
      #   - Stop first if a VM is up that this agent did not start, so the
      #     foreground start can never short-circuit to "already running".
      #     Graceful stop so containers checkpoint; --force only if that hangs,
      #     which it does on a wedged instance.
      #   - Force-stop AFTER any failed start, so the next KeepAlive retry begins
      #     from a genuinely stopped instance. Cleaning up after the failure
      #     rather than probing for it beforehand means this keeps working when
      #     colima rewords its diagnostics.
      #   - No `exec`: the wrapper has to outlive the start to do that cleanup.
      #     launchd supervises the wrapper, which keeps SuccessfulExit = false
      #     meaning what it says — a deliberate `colima stop` exits 0 through
      #     both and stays stopped.
      #
      # Cost of the stop-first: a darwin-rebuild bounces containers. The SIGTERM
      # already did that anyway; now it comes back supervised.
      #
      # The start flags mirror what services.colima would have passed for this
      # profile — --save-config=false because `settings` below is non-empty, so
      # colima.yaml is a read-only store symlink it must not try to rewrite.
      startColima = pkgs.writeShellScript "start-colima" ''
        if ${colima} status default >/dev/null 2>&1; then
          echo "colima: a VM is up that this agent does not own — restarting it"
          ${colima} stop default || ${colima} stop default --force || true
        fi

        if ${colima} start default -f --activate=true --save-config=false; then
          exit 0
        fi

        echo "colima: start failed — forcing a stop so the retry is not wedged"
        ${colima} stop default --force || true
        exit 1
      '';
    in
    {
      # colima itself comes from services.colima.package, not listed here.
      home.packages = with pkgs; [
        docker-client # the `docker` CLI (no engine — the engine runs in colima)
        docker-compose
        docker-buildx
      ];

      # Docker discovers subcommands as plugins under ~/.docker/cli-plugins,
      # which makes `docker compose` and `docker buildx` work (not just the
      # standalone binaries). This does not touch ~/.docker/config.json.
      #
      # programs.docker-cli is deliberately left OFF: it would take over
      # ~/.docker/config.json, which is hand-managed here and holds the
      # credHelpers entry for us-east4-docker.pkg.dev. services.colima only
      # writes through that module, so leaving it off keeps the file ours.
      home.file.".docker/cli-plugins/docker-compose".source =
        "${pkgs.docker-compose}/bin/docker-compose";
      home.file.".docker/cli-plugins/docker-buildx".source =
        "${pkgs.docker-buildx}/bin/docker-buildx";

      services.colima = {
        enable = true;

        # dockerPackage is left at its upstream default of pkgs.docker, which it
        # uses only to run `docker context use` when activating a profile. On
        # darwin that is NOT a second, engine-carrying docker: pkgs.docker and
        # pkgs.docker-client resolve to the identical store path here
        # (docker-29.7.2 — there is no Linux daemon to build), so pinning it
        # would express a distinction that does not exist on this platform.

        profiles.default = {
          isService = true;
          # Sets the docker context to "colima". Already what ~/.docker/
          # config.json says by hand; this makes it declarative.
          isActive = true;
          # Not setDockerHost: that flips on at stateVersion 26.05 upstream, and
          # the docker context already resolves the socket. Setting DOCKER_HOST
          # too would give two sources of truth for one answer.

          # Combined stdout+stderr. Overrides the upstream default of
          # $XDG_STATE_HOME/colima/default.log because launchd refuses to start a
          # job whose log directory does not exist, and ~/Library/Logs always
          # does (it is also where Console.app looks).
          logFile = "${config.home.homeDirectory}/Library/Logs/colima.log";

          # Transcribed from the imperative ~/.colima/default/colima.yaml this
          # replaces, VERBATIM and in full — including the fields colima derives
          # at runtime (arch, gatewayAddress, hostname). Deliberately complete
          # rather than a diff against colima's template: with --save-config=false
          # this file IS the config, and an omitted key reaches colima's structs
          # as a zero value, so a partial spec would silently boot a 0-CPU VM.
          #
          # To resize, edit cpu/memory/disk here and rebuild — NOT `colima start
          # --cpu N`, which now writes to a read-only store symlink.
          settings = {
            cpu = 2;
            disk = 100;
            memory = 2;
            arch = "aarch64";
            runtime = "docker";
            modelRunner = "docker";
            hostname = "colima";
            kubernetes = {
              enabled = false;
              version = "v1.35.0+k3s1";
              k3sArgs = [ "--disable=traefik" ];
              port = 0;
            };
            autoActivate = true;
            network = {
              address = false;
              mode = "shared";
              interface = "en0";
              preferredRoute = false;
              dns = null;
              dnsHosts = { };
              hostAddresses = false;
              gatewayAddress = "192.168.5.2";
            };
            forwardAgent = false;
            docker = { };
            # vz = Virtualization.framework, virtiofs = its native mount path.
            # Both are the fast Apple-Silicon options; do not fall back to
            # qemu/sshfs without measuring.
            vmType = "vz";
            portForwarder = "ssh";
            rosetta = false;
            binfmt = true;
            nestedVirtualization = false;
            mountType = "virtiofs";
            mountInotify = false;
            cpuType = "";
            provision = null;
            sshConfig = true;
            sshPort = 0;
            mounts = [ ];
            diskImage = "";
            forceDiskImage = false;
            rootDisk = 20;
            env = { };
          };
        };
      };

      # Supervision only — everything else about the agent (EnvironmentVariables,
      # the hermetic PATH, COLIMA_HOME, the log paths) is upstream's and is
      # inherited. The agent is named after the profile: colima-default.
      launchd.agents.colima-default.config = {
        ProgramArguments = lib.mkForce [ "${startColima}" ];
        KeepAlive = lib.mkForce { SuccessfulExit = false; };
        # Not launchd's 10s default: when a start does fail repeatedly, that
        # default burned ~8600 log lines a day here (1.8 MB in three weeks).
        ThrottleInterval = 60;
      };
    };
}
