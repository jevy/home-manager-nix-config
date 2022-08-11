{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    taskwarrior
    taskwarrior-tui
    tasksh
  ];

  home.shellAliases = {
    # Taskwarrior
    tr = "clear && task ready";
    t = "clear && task";
    tt = "taskwarrior-tui";
    tw = "task waiting";
    tin = "task add +in";
  };

  home.file = {
    ".taskrc".source = taskwarrior/taskrc;
  };

  services.taskwarrior-sync.enable = true;

}