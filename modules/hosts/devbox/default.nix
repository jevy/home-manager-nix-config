# The in-cluster devbox: a headless herdr session server running in a
# Kubernetes pod (home-infrastructure-flux `apps/devbox`). Standalone
# home-manager — NOT the NixOS integration linux-server-base.nix uses — because
# a pod has no systemd and no bootloader.
#
# User is `dev`, home is /home/dev; both the nix store and the home live on a
# Longhorn PVC. The pod activates this configuration by flake ref at a pinned
# rev (`apps/devbox/home-config-rev` over there), substituting from
# cache.nixos.org — there is no private binary cache. Measured: 29 of the
# closure's 1166 paths are missing from cache.nixos.org, and all but
# claude-code and claude-code-router are text-file derivations.
#
# Lean module set on purpose: no nixvim (large closure, the agent edits files
# itself), no tuicr/hunk/pickr/reviewr (forge review tooling; the flux repo
# commits straight to main), no desktop modules. Adding one later is a commit
# here plus a bump of apps/devbox/home-config-rev in home-infrastructure-flux.
#
# One module from the intended set is deliberately ABSENT:
#
#   * homeManager.ssh — sets `IdentityFile` to a sops secret path, and the pod
#     holds no PGP/age key by design (see the spec's "No sops capability in the
#     pod"), so importing `homeManager.sops` to get the option declared would
#     only move the failure from eval time to activation time. Nothing is lost:
#     the pod's ssh identity is the GitHub deploy key that bootstrap.sh
#     installs from a mounted Kubernetes Secret.
#
# `homeManager.mcp` IS imported, restricted by `local.mcp.only` below. It was
# absent originally because two wrappers (truenas, github) interpolated a sops
# path at eval time; both now read their token by guarded literal path, the
# same way grafana/brave/n8n always did, so the module evaluates with no sops
# at all.
#
# `homeManager.cliBase` is sops-free (the sops-using CLI bits live in
# `cliLinux`, which is not imported here) and so is safe to take whole.
{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager;
  system = "x86_64-linux";

  # Declared directly rather than through `configurations.home` (modules/home.nix)
  # because that helper takes `inputs.nixpkgs.legacyPackages.<system>`, which has
  # no `allowUnfree` — and `homeManager.claudeCode` installs pkgs.claude-code,
  # which is unfree. Passing `pkgs` to homeManagerConfiguration makes the
  # `nixpkgs.config` home-manager option inert, so the predicate has to be set
  # on the instantiation itself.
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [
      # context7-mcp, mcp-server-git and mcp-server-time come from here, so
      # homeManager.mcp does not evaluate without it.
      inputs.mcp-servers-nix.overlays.default
      (_final: prev: {
        # `numr` (a calculator TUI, pulled in by cliBase) does not build against
        # the current nixpkgs: its numr-editor crate fails with 84 instances of
        # "requires panic strategy `abort` which is incompatible with this
        # crate's strategy of `unwind`". cache.nixos.org has no copy either
        # (narinfo 404), so there is nothing to substitute.
        #
        # This is NOT a devbox regression — it is latent breakage in cliBase
        # that the Lenovo never notices, because a working numr from an older
        # rustc is already in its local store. A from-scratch build of any host
        # would hit the same wall. Discovered by the devbox closure CI job,
        # which builds on a clean runner.
        #
        # Stubbed rather than removed because cliBase is shared with every host
        # and dropping the package there is a decision for those hosts too. A
        # devbox has no use for a calculator TUI, so an empty derivation costs
        # nothing here. Delete this overlay once numr builds again.
        numr = prev.runCommand "numr-stubbed-out" { } "mkdir -p $out";
      })
    ];
  };
in
{
  flake.homeConfigurations.devbox = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      homeManager.zsh
      homeManager.cliBase
      homeManager.git
      homeManager.direnv
      homeManager.herdr
      homeManager.claudeCode
      homeManager.mcp
      {
        # The subset the pod can actually run. Everything here needs either
        # nothing at all, or an env var the Kubernetes Secret already supplies:
        #
        #   context7, git, time   no credentials
        #   kubernetes            the pod's ServiceAccount kubeconfig
        #   grafana               GRAFANA_SERVICE_ACCOUNT_TOKEN from the Secret
        #   brave-search          BRAVE_API_KEY from the Secret
        #
        # Left out: playwright (chromium, and no display to drive it),
        # homeassistant and n8n (tokens not in the Secret yet — add the key
        # there and the name here), truenas and linear (same, plus linear wants
        # an interactive OAuth flow).
        local.mcp.only = [
          "context7"
          "git"
          "time"
          "kubernetes"
          "grafana"
          "brave-search"
        ];

        home.username = "dev";
        home.homeDirectory = "/home/dev";
        home.stateVersion = "24.11";

        # sshd runs in-pod as this user on :2222; bootstrap.sh also installs
        # openssh via `nix profile` before home-manager has ever run, so the pod
        # is reachable on first boot. Having it here too means the profile copy
        # is redundant once activation succeeds, not load-bearing.
        #
        # Everything after openssh is base userland that `cliBase` takes for
        # granted because every other host is NixOS and gets it from
        # environment.systemPackages. A bare nixos/nix container has none of it:
        # without this an SSH session has no `ls`, `cat`, `grep` or `whoami`.
        home.packages = with pkgs; [
          openssh
          coreutils
          findutils
          diffutils
          gnugrep
          gnused
          gawk
          gnutar
          gzip
          procps
          util-linux
          less
          which
          bashInteractive
        ];

        # home-manager's hm-session-vars.sh sets FZF and locale variables but
        # never touches PATH, and the profile has no nix.sh either — on NixOS
        # the system PATH covers this, in a container nothing does. Without it
        # an SSH session inherits only sshd's compiled-in default and cannot see
        # a single installed package. login-shell in the flux repo sets the same
        # PATH defensively; this is the declarative half.
        home.sessionPath = [ "$HOME/.nix-profile/bin" ];

        # Distinguishes commits pushed from the pod in `git log`. bootstrap.sh
        # repeats this repo-locally, so the identity is right even if activation
        # has not happened yet.
        programs.git.settings.user = {
          name = "Jevin (devbox)";
          email = "jevin@quickjack.ca";
        };

        # Every herdr pane lands in the flux repo's devenv shell.
        #
        # Deliberately NOT `exec devenv shell`: this is the only shell on a
        # machine reachable only over SSH, so a devenv failure that replaced the
        # login shell would be a lockout. Nesting instead costs one extra shell
        # level and degrades to a plain zsh prompt when devenv is unhappy.
        programs.zsh.initContent = ''
          if [ -z "''${DEVENV_ROOT:-}" ] && [ -d "$HOME/home-infrastructure-flux" ]; then
            cd "$HOME/home-infrastructure-flux"
            if command -v devenv >/dev/null 2>&1; then
              devenv shell || echo "devenv shell failed; staying in plain zsh" >&2
            fi
          fi
        '';
      }
    ];
  };
}
