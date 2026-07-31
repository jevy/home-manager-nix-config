# Docker on macOS (mac-work host).
#
# macOS has no Linux kernel, so the Docker *daemon* can't run natively — it
# needs a Linux VM. Colima provides that: a lightweight VM (Apple's
# Virtualization.framework on Apple Silicon) running the Docker engine, driven
# entirely from the CLI. This is the Nix-native alternative to Docker Desktop
# (no Homebrew, no proprietary licence).
#
# This is a home-manager module (not nix-darwin / NixOS): there's no
# virtualisation.docker on darwin, and the docker CLI belongs in the same
# profile as docker-credential-gcloud (already installed via google-cloud-sdk
# in shell/cli.nix). Co-locating them satisfies gcloud's requirement that
# `docker` and `docker-credential-gcloud` share a PATH, so the Google Artifact
# Registry credential helper (us-east4-docker.pkg.dev in ~/.docker/config.json)
# works for pulls/pushes.
{ ... }:
{
  flake.modules.homeManager.dockerMac =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [
        docker-client # the `docker` CLI (no engine — the engine runs in colima)
        docker-compose
        docker-buildx
        colima
      ];

      # Docker discovers subcommands as plugins under ~/.docker/cli-plugins,
      # which makes `docker compose` and `docker buildx` work (not just the
      # standalone binaries). This does not touch ~/.docker/config.json.
      home.file.".docker/cli-plugins/docker-compose".source =
        "${pkgs.docker-compose}/bin/docker-compose";
      home.file.".docker/cli-plugins/docker-buildx".source =
        "${pkgs.docker-buildx}/bin/docker-buildx";

      # Start the colima VM at login and keep it running, so `docker` is always
      # available. `--foreground` keeps the process attached for launchd to
      # supervise; KeepAlive.SuccessfulExit = false restarts it on a crash but
      # still lets a manual `colima stop` (clean exit) actually stop it.
      # Colima's default is 2 CPU / 2 GB RAM / 60 GB disk — bump with
      # `colima start --cpu N --memory N` (persists across restarts) if builds
      # need more.
      launchd.agents.colima = {
        enable = true;
        config = {
          ProgramArguments = [ "${pkgs.colima}/bin/colima" "start" "--foreground" ];
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/colima.out.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/colima.err.log";
          EnvironmentVariables = {
            HOME = config.home.homeDirectory;
            PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
        };
      };
    };
}
