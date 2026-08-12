# macOS work laptop host definition (nix-darwin + home-manager).
#
# Migrated from standalone home-manager (2026-07-31). Standalone HM is
# user-scoped and can't make GUI apps discoverable by Spotlight — its app
# symlinks land in ~/Applications pointing into /nix, which LaunchServices
# refuses to index. nix-darwin activates as root and runs the same mkalias
# trampoline nix-darwin uses for system apps into /Applications/Nix Apps (a
# location Spotlight *does* index). That aliaser only covers
# environment.systemPackages, so GUI apps that need to appear in Spotlight
# (linear, ghostty, neovide) are declared as system packages below; their
# home-manager modules still own the app config.
#
# Nix itself is owned by the Determinate nix-installer on this machine, so
# nix.enable = false — nix-darwin manages the system, not the Nix install.
{ config, inputs, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
  inherit (config.flake) overlays;
in
{
  configurations.darwin.mac-work.module =
    { pkgs, ... }:
    {
      imports = [
        inputs.home-manager.darwinModules.home-manager

        # Installs the BlackHole 2ch HAL plug-in into /Library (root-owned);
        # its home-manager half below runs the bridge that feeds it.
        darwin.monoMic

        # Tiling, directional focus and workspaces. Replaced
        # homeManager.rectangle, which could only place the focused window,
        # and darwin.macSpaces, whose native Ctrl+1..6 Space switching
        # AeroSpace's own workspaces supersede.
        darwin.aerospace
      ];

      nixpkgs.hostPlatform = "aarch64-darwin";
      nixpkgs.overlays = [ overlays.volsync ];
      # linear (and other work apps) are unfree; matches the NixOS hosts.
      nixpkgs.config.allowUnfree = true;

      # Determinate nix-installer owns the Nix installation and daemon here;
      # nix-darwin must not try to manage or reconfigure it.
      nix.enable = false;

      # nix-darwin manages /etc/zshrc so login shells get the system profile
      # (/run/current-system/sw/bin → darwin-rebuild) and the per-user profile
      # (/etc/profiles/per-user/jevin/bin → home-manager packages incl. docker)
      # on PATH. This defaults to true; set explicitly so a future default flip
      # can't silently push useUserPackages installs off-PATH. The per-user zsh
      # config still comes from home-manager's programs.zsh.
      programs.zsh.enable = true;

      system.stateVersion = 6;
      system.primaryUser = "jevin";
      users.users.jevin.home = "/Users/jevin";

      # Touch ID for sudo, so `rebuildhm` (sudo darwin-rebuild) takes a
      # fingerprint instead of a password. nix-darwin writes pam_tid.so into
      # /etc/pam.d/sudo_local, the drop-in Apple added precisely so this
      # survives OS updates (editing /etc/pam.d/sudo directly does not).
      # Also accepts an unlocked Apple Watch.
      #
      # Not enabling `reattach` here: that's only needed for tmux/screen, which
      # this config doesn't install. Add it if that changes.
      security.pam.services.sudo_local.touchIdAuth = true;

      # Caps → Ctrl. The old standalone config expressed this via
      # home.keyboard.options = [ "ctrl:nocaps" ], which is setxkbmap (Linux
      # only) and silently did nothing on macOS. nix-darwin does it natively.
      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      # GUI apps that must be Spotlight-launchable. nix-darwin aliases these
      # into /Applications/Nix Apps on activation. ghostty/neovide are also
      # configured via their home-manager modules (same store path — the extra
      # reference is just one more symlink, no disk cost).
      environment.systemPackages = with pkgs; [
        ghostty-bin
        neovide
        linear
        # Feishin ships a real .app; declaring it here (rather than only in the
        # navidrome home-manager module) is what gets it into Spotlight.
        feishin
        # AeroSpace is NOT listed here: services.aerospace adds its package to
        # environment.systemPackages itself, so it gets the Nix Apps alias (and
        # therefore the Accessibility dialog) for free.
        #
        # AltTab needs BOTH Accessibility and Screen Recording
        # granted by hand, so it has to be pickable in those dialogs.
        alt-tab-macos
      ];

      # useGlobalPkgs is intentionally left false: stylix's home-manager module
      # injects nixpkgs.overlays (nixos-icons, gtksourceview) at the HM level,
      # which conflicts with useGlobalPkgs (deprecation warning, breaks later).
      # So home-manager keeps its own nixpkgs and sets config/overlays below.
      home-manager = {
        useUserPackages = true;
        users.jevin =
          { ... }:
          {
            nixpkgs.overlays = [ overlays.volsync ];
            nixpkgs.config.allowUnfree = true;

            imports = [
              # Shell & CLI
              homeManager.zsh
              homeManager.cliBase
              homeManager.ghostty

              # Development
              homeManager.nixvim
              homeManager.nixvimVscode
              homeManager.neovide
              homeManager.direnv
              homeManager.git
              homeManager.gitSpice
              homeManager.hunk
              homeManager.herdr
              homeManager.tuicr
              homeManager.flowgraph
              homeManager.claudeCode
              homeManager.dockerMac

              # Desktop (Mac-specific)
              homeManager.desktopMac
              homeManager.altTab
              homeManager.monoMic
              homeManager.macFonts
              homeManager.stylix

              # Music (ferrosonic TUI + feishin GUI against navidrome.jevy.org)
              homeManager.navidrome

              # Work-Specific
              homeManager.taskwarrior
              homeManager.onepasswordCli

              # Secrets
              homeManager.sops

              # SSH
              homeManager.ssh
            ];

            home.stateVersion = "23.11";
            programs.home-manager.enable = true;

            home.username = "jevin";
            home.homeDirectory = "/Users/jevin";

            # Mac work zsh init (from zsh-spellbook.nix)
            programs.zsh = {
              initContent = ''
                export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"  # Added by n-install (see http://git.io/n-install-repo).
                [[ :$PATH: == *":$HOME/go/bin:"* ]] || PATH+=":$HOME/go/bin"; export PATH
                export LOCAL_BIN="$HOME/.local/bin"; [[ :$PATH: == *":$LOCAL_BIN:"* ]] || PATH+=":$LOCAL_BIN"
                if [[ -f /Users/jevin/secrets/node_auth ]]; then
                  export NODE_AUTH_TOKEN=$(< /Users/jevin/secrets/node_auth)
                fi
                if [[ -f /Users/jevin/secrets/localstack ]]; then
                  export LOCALSTACK_AUTH_TOKEN=$(< /Users/jevin/secrets/localstack)
                fi
                # Clear API keys to avoid using personal keys at work
                unset ANTHROPIC_API_KEY
                unset OPENAI_API_KEY
                unset GEMINI_API_KEY
              '';
            };

            home.shellAliases = {
              pomodoro = "termdown 25m -s -b";
            };
          };
      };
    };
}
