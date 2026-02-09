# macOS work laptop host definition (standalone home-manager)
{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager;
  inherit (config.flake) overlays;
in
{
  configurations.home.mac-work = {
    system = "aarch64-darwin";
    module = { pkgs, ... }: {
      imports = [
        # Shell & CLI
        homeManager.zsh
        homeManager.cliBase
        homeManager.ghostty

        # Development
        homeManager.nixvim
        homeManager.nixvimVscode
        homeManager.git

        # Desktop (Mac-specific)
        homeManager.desktopMac
        homeManager.stylix

        # Work-Specific
        homeManager.taskwarrior

        # Secrets
        homeManager.sops
      ];

      nixpkgs.overlays = [
        overlays.volsync
        overlays.tailscale
      ];

      home.stateVersion = "23.11";
      programs.home-manager.enable = true;

      home.username = "jevin";
      home.homeDirectory = "/Users/jevin";

      home.keyboard = {
        layout = "us";
        variant = "qwerty";
        options = [ "ctrl:nocaps" ];
      };

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

      programs.difftastic = {
        enable = true;
        git.enable = true;
      };
    };
  };
}
