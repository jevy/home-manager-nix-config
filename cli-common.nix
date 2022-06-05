{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    visidata
    wget
    neofetch
    ranger
    git
    speedtest-cli
    k9s
    kubectl
    ripgrep
    ripgrep-all
    file
    ffmpeg
    killall
    dig
    ldns # drill
    unzip
    fzf # For ranger
    yt-dlp
    tmux
    termdown
    httpie
    kubectx
    pandoc
    zip
    lsd
    fd
    feh
    taskwarrior
    taskwarrior-tui
    tasksh
    ncdu
    bat
  ];

  home.file = {
    ".config/ranger".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nixpkgs/ranger";
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
    ls = "lsd";
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";

    # Taskwarrior
    tr = "clear && task ready";
    t = "clear && task";
    tt = "taskwarrior-tui";

    # Todoist
    ts = "todoist s"; #Sync
    tl ="todoist list --filter '(overdue | today)'"; # Today
  };

}
