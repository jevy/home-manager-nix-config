{
  config,
  pkgs,
  libs,
  ...
}: {
  home.packages = with pkgs; [
    taskwarrior3
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
}
