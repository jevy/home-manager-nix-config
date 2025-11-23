{
  config,
  pkgs,
  libs,
  ...
}: {
  programs.fzf = {
    enable = true;
    # enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # autosuggestion.enable = true;
    initContent = ''
      if [ -f "${config.home.homeDirectory}/.config/zsh/api_keys.zsh" ]; then
        source "${config.home.homeDirectory}/.config/zsh/api_keys.zsh"
      fi

      # Ensure Nix paths are at the front of $PATH (some plugins reorder it)
      nix_user_path="$HOME/.nix-profile/bin"
      nix_system_path="/nix/var/nix/profiles/default/bin"
      export PATH="$nix_user_path:$nix_system_path:$(echo "$PATH" | tr ':' '\n' \
        | grep -v "$nix_user_path" | grep -v "$nix_system_path" | paste -sd: -)"
    '';
    envExtra = ''
      if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
    '';
    plugins = [
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "chisui";
          repo = "zsh-nix-shell";
          rev = "v0.8.0";
          sha256 = "1lzrn0n4fxfcgg65v0qhnj7wnybybqzs4adz7xsrkgmcsr0ii8b7";
        };
      }
      {
        name = "vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
      {
        name = "powerlevel10k";
        file = "powerlevel10k.zsh-theme";
        src = pkgs.fetchFromGitHub {
          owner = "romkatv";
          repo = "powerlevel10k";
          rev = "v1.20.0";
          sha256 = "ES5vJXHjAKw/VHjWs8Au/3R+/aotSbY7PWnWAMzCR8E=";
        };
      }
      {
        name = "powerlevel10k-config";
        file = "p10k.zsh";
        src = pkgs.lib.cleanSource ./p10k;
      }
    ];
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "ruby"
        "rails"
        "kubectl"
        "taskwarrior"
        "systemd"
        "aws"
        "fluxcd"
        "helm"
        "man"
        "tmux"
        "docker-compose"
        "docker"
      ];
    };
  };
}
