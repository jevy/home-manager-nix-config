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
  ];

  home.file = {
    "./.config/ranger".source = config.lib.file.mkOutOfStoreSymlink /home/jevin/.config/nixpkgs/ranger;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
    ls = "lsd";
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";
  };

}
