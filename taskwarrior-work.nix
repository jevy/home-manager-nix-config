{ config, pkgs, libs, ... }:
let
    relative-recur = pkgs.fetchFromGitHub {
      owner  = "JensErat";
      repo   = "task-relative-recur";
      rev    = "161e1a9e2605c256e56f4aaf494e2041008d8b57";
      sha256 = "0I6grsjvMOfI4KJWo6xfjkUqntRSPfEtAh47igIEIBI=";
  };
in
{

  home.packages = with pkgs; [
    taskwarrior
    taskwarrior-tui
    # tasksh
    # taskopen
  ];

  home.shellAliases = {
    # Taskwarrior
    tr = "clear && task ready";
    t = "clear && task";
    tt = "taskwarrior-tui";
    tw = "task waiting";
    tin = "task add +in";
  };


  # home.file = {
  #   ".taskrc".source = taskwarrior/taskrc;
  #   ".task/hooks/on-modify.relative-recur" = {
  #     source = "${relative-recur}/on-modify.relative-recur";
  #     executable = true;
  #   };
  # };

  # services.taskwarrior-sync.enable = true;

}
