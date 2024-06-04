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
    icons = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # autosuggestion.enable = true;
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
      ];
    };
  };
}
