# macOS work laptop host definition (nix-darwin + home-manager).
#
# Migrated from standalone home-manager (2026-07-31). Standalone HM is
# user-scoped and can't make GUI apps discoverable by Spotlight — its app
# symlinks land in ~/Applications pointing into /nix, which LaunchServices
# refuses to index. nix-darwin activates as root and runs the same mkalias
# trampoline nix-darwin uses for system apps into /Applications/Nix Apps (a
# location Spotlight *does* index). That aliaser only covers
# environment.systemPackages, so GUI apps that need to appear in Spotlight
# (ghostty, neovide, feishin) are declared as system packages below; their
# home-manager modules still own the app config.
#
# Nix itself is owned by the Determinate nix-installer on this machine, so
# nix.enable = false — nix-darwin manages the system, not the Nix install.
{ config, inputs, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
  inherit (config.flake) overlays;

  # WHICH TILING WINDOW MANAGER IS ACTIVE. Exactly one, ever — two window
  # managers both claiming Accessibility will fight over every window, so this
  # is a selector rather than two independent toggles.
  #
  # "aerospace" is the incumbent: workspaces without touching Mission Control,
  # no SIP question, and its own hotkeys. Its limit is that it cannot tile an
  # empty slot, so the 25/50/25 centred-master layout only works with three
  # windows (modules/desktop/aerospace.nix).
  #
  # "yabai" is the alternative, and the reason is that one limit: with SIP still
  # fully enabled, `space --padding` plus `window --ratio` express the same
  # layout for one and two windows too, tiled, with nothing floating. It costs
  # native macOS Spaces you must create by hand, a second daemon for keys
  # (skhd), an Accessibility grant that has to be renewed on every version bump,
  # and "Displays have separate Spaces" turned on (which yabai refuses to start
  # without). VERIFIED live on macOS 26.6 with SIP enabled — the measurements are
  # in modules/desktop/yabai.nix's header.
  windowManager = "yabai";
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
        #
        # Selected by `windowManager` above — never both at once.
        darwin.${windowManager}

        # Key-event viewers, for aiming AeroSpace bindings at a custom
        # keyboard layout. Diagnostic only — nothing starts at login.
        darwin.keyInspect

        # Next calendar event in the menu bar. An LSUIElement app needing
        # hand-granted Calendar access, so it goes through the darwin layer to
        # land in /Applications/Nix Apps as a real copy rather than a
        # user-scoped symlink into /nix — see the module header.
        darwin.meetingbar
      ];

      nixpkgs.hostPlatform = "aarch64-darwin";
      nixpkgs.overlays = [ overlays.volsync ];
      # Nothing in systemPackages currently needs this (linear, the one unfree
      # system app, is no longer Nix-managed) — kept on deliberately so adding a
      # work app later doesn't hit an eval failure. Matches the NixOS hosts. The
      # HM block below sets its own; it does not inherit this one.
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
      #
      # NOTE this disagrees with the Linux hosts on purpose-by-accident: kanata
      # makes Caps a plain Esc and moved Ctrl to the home row to spare the left
      # pinky (see the ulnar-nerve note in modules/services/kanata.nix). Keep
      # Caps→Ctrl only as the fallback for the built-in keyboard, which has no
      # kanata and no home-row mods; on the Voyager, Ctrl comes from the keys
      # below. Switch to remapCapsLockToEscape if the laptop keyboard stops
      # being used bare.
      #
      # NO Ctrl/⌘ REMAPPING HERE, DELIBERATELY. The Voyager's own Mac layer
      # already solves it, and an OS-level remap would fight the firmware.
      #
      # The friction being avoided: on Linux one Ctrl serves two jobs — app
      # commands (Ctrl+C copies) and terminal control codes (Ctrl+C interrupts).
      # macOS necessarily splits those across ⌘ and ⌃.
      #
      # The firmware resolves the app-command half exactly right, by making the
      # f-hold/j-hold home-row mods emit whatever the host calls "app command":
      # Ctrl on the Linux layer, ⌘ on the Mac layer. Every GUI chord is then one
      # identical motion on both machines — f-hold+L is Ctrl+L in Firefox on
      # Linux and ⌘L in Firefox here, f-hold+C copies in both, and so on. Do not
      # "fix" this from Nix; it is already correct, and a hidutil Ctrl↔⌘ swap
      # would double-apply on top of the layer.
      #
      # What the firmware leaves orphaned is the OTHER half: with f/j spent on ⌘,
      # the Mac layer has no home-row Ctrl, so terminal control codes have
      # nowhere to come from. That wants a dedicated THUMB sending plain Ctrl on
      # BOTH layers — a thumb because terminal Ctrl targets span both hands
      # (Ctrl+A/C/D/R/W/E and Ctrl+H/L/U/K/N/P) and a thumb has no same-finger
      # collision with any letter, unlike f-hold+R or f-hold+V where the index
      # would have to hold the mod and press the letter above/below it.
      #
      # That yields one rule true on both machines:
      #
      #   home row (f/j) -> talk to the APP      (Ctrl on Linux, ⌘ here)
      #   thumb          -> talk to the TERMINAL (Ctrl on both)
      #
      # and it is free to learn: on the Linux layer the thumb is a redundant
      # Ctrl, so thumb+C already interrupts there today. Nothing to configure on
      # this side — which is why this block stays a bare Caps remap.
      #
      # (The terminal half needs no Nix help either: modules/shell/ghostty.nix
      # puts the ctrl+a leader and ctrl+h/l splits in the *base* keybind list
      # rather than the Darwin one, so every terminal chord is already identical
      # across platforms.)
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
        # Linear is deliberately NOT managed by Nix: it self-updates and is
        # installed by hand from linear.app into /Applications.
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
            # mcpServers overlay: context7-mcp, mcp-server-git and
            # mcp-server-time come from mcp-servers-nix — homeManager.mcp
            # does not evaluate without it (same note as the devbox host).
            nixpkgs.overlays = [ overlays.volsync overlays.mcpServers ];
            # Needed at the HM level for 1password-cli (homeManager.
            # onepasswordCli). Not inherited from the darwin-level setting
            # above: useGlobalPkgs is off, so HM instantiates its own nixpkgs.
            nixpkgs.config.allowUnfree = true;

            imports = [
              # Shell & CLI
              homeManager.zsh
              homeManager.cliBase
              homeManager.ghostty
              homeManager.nosleepMac

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
              homeManager.opencodeMac
              homeManager.dockerMac
              homeManager.llmfit
              homeManager.llamaSwapMac
              homeManager.piDarwin
              homeManager.mcp
              {
                # Only the lightweight/local ones. playwright is out because
                # its wrapper hard-codes pkgs.chromium as the browser
                # executable, and chromium is Linux-only in nixpkgs
                # (`lib.getAttrs` never forces the excluded server, so
                # chromium stays out of the closure). context7, kubernetes,
                # grafana, n8n, truenas and homeassistant are out by
                # preference — not wanted on this machine. brave-search's key
                # is in the shared secrets.yaml and decrypts here via
                # homeManager.sops.
                local.mcp.only = [
                  "git"
                  "time"
                  "brave-search"
                  "linear"
                ];
              }

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
