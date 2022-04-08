{ config, pkgs, libs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    plugins = [
        {
          name = "todoist-functions";
          src = pkgs.fetchFromGitHub {
            owner = "sachaos";
            repo = "todoist";
            rev = "v0.16.0";
            sha256 = "cfhwbL7RaeD5LWxlfqnHfPPPkC5AA3Z034p+hlFBWtg=";
          };
          file = "todoist_functions.sh";
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
