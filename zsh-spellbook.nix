{pkgs, ...}: {
  home.shellAliases = {
    pomodoro = "${pkgs.termdown}/bin/termdown 25m -s -b";
  };
}
