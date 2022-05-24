{ config, pkgs, libs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
    '';
    plugins = [
        {
          name = "zsh-z";
          file = "zsh-z.plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "agkozak";
            repo = "zsh-z";
            rev = "b5e61d03a42a84e9690de12915a006b6745c2a5f";
            sha256 = "1A6WZ+fJSf2WKZD7CYJB/pbgwV2mX+X8qInqQLeuT78=";
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
      ];
    };
  };
}
