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
          src = pkgs.fetchFromGitHub {
            owner = "agkozak";
            repo = "zsh-z";
            rev = "b5e61d03a42a84e9690de12915a006b6745c2a5f";
            sha256 = "1A6WZ+fJSf2WKZD7CYJB/pbgwV2mX+X8qInqQLeuT78=";
          };
          file = "zsh-z.plugin.zsh";
        }
    # plugins = [
    #     {
    #       file = "powerlevel10k.zsh-theme";
    #       name = "powerlevel10k";
    #       src = pkgs.fetchFromGitHub {
    #         owner = "romkatv";
    #         repo = "powerlevel10k";
    #         rev = "v1.16.1";
    #         sha256 = "DLiKH12oqaaVChRqY0Q5oxVjziZdW/PfnRW1fCSCbjo=";
    #       };
    #     }
    #     # {
    #     #   file = "p10k.zsh";
    #     #   name = "powerlevel10k-config";
    #     #   src = p10k/p10k.zsh;
    #     # }
    ];
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      # theme = "powerlevel10k/powerlevel10k";
      plugins = [ 
        "git"
        "ruby"
        "rails"
        "sudo"
        "kubectl"
        "taskwarrior"
      ];
    };

    # TODO: Need to source my p10k Properly
    # plugins = with pkgs; [
    #   {
    #     file = "powerlevel10k.zsh-theme";
    #     name = "powerlevel10k";
    #     src = pkgs.fetchFromGitHub {
    #       owner = "romkatv";
    #       repo = "powerlevel10k";
    #       rev = "v1.16.1";
    #       sha256 = "DLiKH12oqaaVChRqY0Q5oxVjziZdW/PfnRW1fCSCbjo=";
    #     };
    #   }
    #   {
    #     file = "p10k.zsh";
    #     name = "powerlevel10k-config";
    #     src = ./config/zsh/p10k;
    #   }
    # ];
  };
  home.file = {
    ".p10k.zsh".source = p10k/p10k.zsh;
  };
}
