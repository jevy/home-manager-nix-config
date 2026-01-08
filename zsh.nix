{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    # FZF_DEFAULT_COMMAND - used when running fzf directly
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    # FZF_DEFAULT_OPTS - default options for all fzf invocations
    defaultOptions = [
      "--height 60%"
      "--border"
      "--layout=reverse"
      "--info=inline"
      "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
      "--preview-window 'right:50%:wrap'"
      "--bind 'ctrl-/:toggle-preview'"
    ];
    # FZF_CTRL_T_COMMAND - file widget (CTRL-T)
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetOptions = [
      "--preview 'bat --color=always --style=numbers --line-range=:500 {}'"
      "--preview-window 'right:60%:wrap'"
    ];
    # FZF_ALT_C_COMMAND - directory widget (ALT-C)
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git | sort";
    changeDirWidgetOptions = [
      "--preview 'eza --tree --level=2 --color=always {}'"
      "--preview-window 'right:60%:wrap'"
    ];
    # FZF_CTRL_R_OPTS - history widget (CTRL-R)
    historyWidgetOptions = [
      "--preview 'echo {}'"
      "--preview-window 'down:3:wrap'"
    ];
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
    dotDir = "${config.xdg.configHome}/zsh";
    shellAliases = {
    };
    # autosuggestion.enable = true;
    initContent = lib.mkMerge [
      # Before plugins (order 900) - set up zsh-vi-mode hook
      (lib.mkOrder 550 ''
        # Re-source fzf keybindings after zsh-vi-mode initializes
        zvm_after_init_commands+=('source <(fzf --zsh)')
      '')
      # Regular init content
      (lib.mkOrder 1000 ''
        f() {
          fzf --query="$*" --bind 'enter:become(nvim {})'
        }

        if [ -f "${config.xdg.configHome}/zsh/api_keys.zsh" ]; then
          source "${config.xdg.configHome}/zsh/api_keys.zsh"
        fi

        # Ensure Nix paths are at the front of $PATH (some plugins reorder it)
        nix_user_path="$HOME/.nix-profile/bin"
        nix_system_path="/nix/var/nix/profiles/default/bin"
        export PATH="$nix_user_path:$nix_system_path:$(echo "$PATH" | tr ':' '\n' \
          | grep -v "$nix_user_path" | grep -v "$nix_system_path" | paste -sd: -)"

        # Enhanced fzf completions
        _fzf_compgen_path() {
          fd --hidden --follow --exclude ".git" . "$1"
        }

        _fzf_compgen_dir() {
          fd --type d --hidden --follow --exclude ".git" . "$1"
        }
      '')
    ];
    envExtra = ''
      if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
    '';
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
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
        "docker-compose"
        "docker"
      ];
    };
  };
}
