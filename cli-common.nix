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
    ncdu
    bat
    vagrant
  ];

  home.sessionVariables = {
    VAGRANT_DEFAULT_PROVIDER = "libvirt";
  };

  home.file = {
    ".config/ranger".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nixpkgs/ranger";
    ".config/bat/config".source = bat/config;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
    ls = "lsd";
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";

    # Todoist
    ts = "todoist s"; #Sync
    tl ="todoist list --filter '(overdue | today)'"; # Today

    fdt = "f() fd $1 -t file -X ls -tr -l);f"; # Search files sort by date
  };

}
