# The in-cluster devbox: a headless herdr session server running in a
# Kubernetes pod (home-infrastructure-flux `apps/devbox`). Standalone
# home-manager — NOT the NixOS integration linux-server-base.nix uses — because
# a pod has no systemd and no bootloader.
#
# User is `dev`, home is /home/dev; both the nix store and the home live on a
# Longhorn PVC. The pod activates this configuration by flake ref at a pinned
# rev (`apps/devbox/home-config-rev` over there), having first pulled the
# closure from the public `jevy-homelab` Cachix cache.
#
# Lean module set on purpose: no nixvim (large closure, the agent edits files
# itself), no tuicr/hunk/pickr/reviewr (forge review tooling; the flux repo
# commits straight to main), no desktop modules. Adding one later is a commit
# here plus a bump of apps/devbox/home-config-rev in home-infrastructure-flux.
#
# Two modules from the intended set are deliberately ABSENT, both for the same
# reason — they reference `config.sops.secrets.<name>.path`, and the pod holds
# no PGP/age key by design (see the spec's "No sops capability in the pod"), so
# importing `homeManager.sops` to get the options declared would only move the
# failure from eval time to activation time:
#
#   * homeManager.ssh — sets `IdentityFile` to a sops secret path. The pod's
#     ssh identity is the GitHub deploy key that bootstrap.sh installs from a
#     mounted Kubernetes Secret, so this module has nothing to contribute.
#   * homeManager.mcp — every wrapper reads its token from
#     ~/.config/sops-nix/secrets, and two (truenas, github) interpolate a sops
#     path at eval time. It also drags in chromium + playwright, which is a
#     large fraction of the closure Cachix has to hold. Restoring MCP here means
#     first splitting the sops-dependent wrappers out of modules/dev/mcp.nix.
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
      {
        home.username = "dev";
        home.homeDirectory = "/home/dev";
        home.stateVersion = "24.11";

        # sshd runs in-pod as this user on :2222; bootstrap.sh also installs
        # openssh via `nix profile` before home-manager has ever run, so the pod
        # is reachable on first boot. Having it here too means the profile copy
        # is redundant once activation succeeds, not load-bearing.
        home.packages = [ pkgs.openssh ];

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
