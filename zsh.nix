{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    zoxide
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
      path+=('$HOME/.local/bin')
      eval "$(dev _hook)"
    '';
    plugins = [
        {
          name = "zsh-nix-shell";
          file = "nix-shell.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "chisui";
            repo = "zsh-nix-shell";
            rev = "v0.5.0";
            sha256 = "0za4aiwwrlawnia4f29msk822rj9bgcygw6a8a6iikiwzjjz0g91";
          };
        }
        {
          name = "fzf-tab";
          file = "fzf-tab.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "Aloxaf";
            repo = "fzf-tab";
            rev = "938eef72e93ddb0609205a663bf0783f4e1b5fae";
            sha256 = "xP0IoCeyZyYU+iKUkIoIAMn75r6R3TJYhAKoQgC1dWg=";
          };
        }
        {
          name = "powerlevel10k";
          file = "powerlevel10k.zsh-theme";
          src = pkgs.fetchFromGitHub {
            owner = "romkatv";
            repo = "powerlevel10k";
            rev = "v1.16.1";
            sha256 = "DLiKH12oqaaVChRqY0Q5oxVjziZdW/PfnRW1fCSCbjo=";
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
        "sudo"
        "kubectl"
        "taskwarrior"
        "zoxide"
        "systemd"
      ];
    };
  };
}
