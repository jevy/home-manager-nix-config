{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    neovide
    gimp
    discord
    firefox
    spotify
    obsidian
    zoom-us
    pavucontrol
    synology-drive-client
    slack
    google-chrome
    ruby
    gnumake
    gcc
    bundix
    python-qt
    kubernetes-helm
    zathura
    xournalpp
    dropbox
    libreoffice
    todoist-electron
    arduino
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
    python38Packages.goobook # mutt
    python38Full
    python38Packages.wxPython_4_0
    hugo
    nodejs-16_x
    networkmanager-l2tp
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
    # helvum
    signal-desktop
    ansible_2_10
    gcalcli
    qalculate-gtk
    apprise
    nasc
    doctl
    qcad
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
    obs-studio
    blueberry
    prusa-slicer
    rpi-imager
    pdfarranger
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
  };

  home.file = {
    ".config/sway/config".source = sway/config;
    ".config/mako/config".source = mako/config;
    ".config/waybar/config".source = waybar/config;
    ".config/waybar/style.css".source = waybar/style.css;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
    ts = "todoist s"; #Sync
    tl ="todoist list --filter '(overdue | today)'"; # Today
  };

}
