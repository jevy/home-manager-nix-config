{ config, pkgs, libs, ... }:

{
  programs.zsh = {
    initExtra = ''
      eval "$(dev _hook)"
    '';
  };
}


