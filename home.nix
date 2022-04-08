{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  # home.username = "jevin";
  # home.homeDirectory = "/home/jevin";

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    fortune
    neovide
    ranger
    gimp
    visidata
    ripgrep-all
    discord
    wget
    firefox
    neofetch
    ranger
    spotify
    obsidian
    git
    zoom-us
    speedtest-cli
    pavucontrol
    synology-drive-client
    kitty
    slack
    k9s
    kubectl
    docker
    docker-compose
    ripgrep
    file
    ffmpeg
    imagemagickBig
    google-chrome
    killall
    ruby
    gnumake
    gcc
    bundix
    python-qt
    dig
    ldns # drill
    kubernetes-helm
    zathura
    xournalpp
    dropbox
    libreoffice
    unzip
    todoist-electron
    # findutils # For ranger
    mlocate # For ranger
    fzf # For ranger
    yt-dlp
    arduino
    kicad
    tmux
    mutt-wizard
    neomutt # mutt-wizard
    curl # mutt-wizard
    isync # mutt-wizard
    msmtp # mutt-wizard
    pass # mutt-wizard
    gnupg # mutt-wizard
    pinentry # mutt-wizard
    notmuch # mutt-wizard
    lieer # mutt-wizard
    w3m # mutt-wizard
    abook # mutt-wizard
    urlscan # mutt-wizard
    poppler_utils # mutt-wizard
    mailcap
    python38Packages.goobook # mutt
    awscli2
    python38Full
    python38Packages.wxPython_4_0
    hugo
    nodejs-16_x
    networkmanager-l2tp
    # qbittorrent
    # pywal
    steam
    wally-cli
    vlc
    # cubicsdr
    # sdrangel
    # gqrx
    # sdrpp-with-sdrplay
    # hamlib_4
    # wsjtx
    # unstable.element-desktop-wayland
    # blueberry
    # helvum
    signal-desktop
    ansible_2_10
    gcalcli
    # unstable.nix-template
    termdown
    httpie
    kubectx
    todoist
    peco # For todoist
    qalculate-gtk
    apprise
    pandoc
    nasc
    doctl
    qcad
    zip
    etcher

    # For Sway
    # ---
    #sway
    #swaylock
    #swayidle
    #waybar
    #wl-clipboard
    #mako # notification daemon
    #rofi
    #rofi-calc
    ##wofi
    #wlsunset
    #pamixer
    #grim
    #swappy
    #slurp
    #clipman
    #brightnessctl
    #autotiling
    #wdisplays
    #copyq
    #kooha
    #wf-recorder
    #jq # For waybar weather

    _1password-gui
  ];

  # wayland.windowManager.sway = {
  #   enable = true;
  #   wrapperFeatures.gtk = true ;
  # };



  home.file = {
    "./.config/ranger".source = config.lib.file.mkOutOfStoreSymlink /home/jevin/.config/nixpkgs/ranger;

    ".config/sway/config".source = sway/config;
    ".config/kitty/kitty.conf".source = kitty/kitty.conf;
    ".config/mutt/muttrc".source = mutt/muttrc;

    # ".config/polybar".source = polybar;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
    ts = "todoist s"; #Sync
    tl ="todoist list --filter '(overdue | today)'"; # Today
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  # programs.home-manager.useGlobalPkgs = true;

  programs.git = {
    enable = true;
    userName = "jevin";
    userEmail = "jevin@quickjack.ca";
    aliases = {
      st = "status";
    };
  };

}
