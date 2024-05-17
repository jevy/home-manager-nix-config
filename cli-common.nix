{
  config,
  pkgs,
  libs,
  ...
}: let
  customRanger = pkgs.ranger.override {
    neoVimSupport = true;
    imagePreviewSupport = true;
  };
in {
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
    termdown
    httpie
    kubectx
    pandoc
    texlive.combined.scheme-full
    zip
    fd
    feh
    ncdu
    curl
    tree
    gh
    devenv
  ];

  programs.bat = {
    enable = true;
  };

  programs.tmux = {
    enable = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    historyLimit = 10000;
    mouse = true;
    prefix = "C-a";
    plugins = with pkgs.tmuxPlugins; [
      power-theme
      vim-tmux-navigator
    ];
    extraConfig = ''
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %
      set-option -g display-time 0
    '';
  };

  home.sessionVariables = {
    VAGRANT_DEFAULT_PROVIDER = "libvirt";
  };

  home.file = {
    ".config/ranger".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/nixpkgs/ranger";
  };

  home.shellAliases = {
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";

    fdt = "f() fd $1 -t file -X ls -tr -l);f"; # Search files sort by date

    geoip = "curl ifconfig.co/json";

    rebuildhm = "cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake '.#x86_64-linux'";

    weather = "${pkgs.curl}/bin/curl https://v2.wttr.in/ottawa";
  };
}
