{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    ranger
    visidata
    ripgrep-all
    wget
    neofetch
    ranger
    git
    speedtest-cli
    kitty
    k9s
    kubectl
    docker
    docker-compose
    ripgrep
    file
    ffmpeg
    imagemagickBig
    killall
    dig
    ldns # drill
    unzip
    mlocate # For ranger
    fzf # For ranger
    yt-dlp
    tmux
    awscli2
    termdown
    httpie
    kubectx
    pandoc
    zip
  ];

  home.file = {
    "./.config/ranger".source = config.lib.file.mkOutOfStoreSymlink /home/jevin/.config/nixpkgs/ranger;

    ".config/kitty/kitty.conf".source = kitty/kitty.conf;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
    ts = "todoist s"; #Sync
    tl ="todoist list --filter '(overdue | today)'"; # Today
  };

}