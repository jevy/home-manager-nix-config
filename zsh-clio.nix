{ pkgs, ... }:

{
  programs.zsh = {
    initExtra = ''
      eval "$(dev _hook)"
    '';
  };
  home.shellAliases = {
    pomodoro = "${pkgs.termdown}/bin/termdown 25m -s -b";
  };
}


