{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
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
    # docker
    # docker-compose  # No darwin
    ripgrep
    file
    ffmpeg
    # imagemagickBig # No darwin
    killall
    dig
    ldns # drill
    unzip
    # mlocate # For ranger # No Darwin
    fzf # For ranger
    yt-dlp
    tmux
    # awscli2 # No AWS
    termdown
    httpie
    kubectx
    pandoc
    zip
    lsd
    fd
    feh
    # usbutils # No Darwin
  ];

  home.file = {
    "./.config/ranger".source = config.lib.file.mkOutOfStoreSymlink /home/jevin/.config/nixpkgs/ranger;

    ".config/kitty/kitty.conf".source = kitty/kitty.conf;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
    ls = "lsd";
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";
  };

}
