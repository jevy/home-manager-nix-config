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
    texlive.combined.scheme-full
    zip
    lsd
    fd
    feh
    ncdu
    bat
    vagrant
    curl
  ];

  home.sessionVariables = {
    VAGRANT_DEFAULT_PROVIDER = "libvirt";
  };

  home.file = {
    ".config/ranger".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nixpkgs/ranger";
    ".config/bat/config".source = bat/config;
  };

  home.shellAliases = {
    ls = "lsd";
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";

    fdt = "f() fd $1 -t file -X ls -tr -l);f"; # Search files sort by date

    geoip = "curl ifconfig.co/json";

    rebuildhm = "cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake .#";

    weather = "${pkgs.curl}/bin/curl https://v2.wttr.in/ottawa";
  };

}
