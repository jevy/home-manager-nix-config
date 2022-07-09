{ config, pkgs, libs, ... }:
{

  home.packages = with pkgs; [
    libreoffice
    # neovide
    neovim-remote
    gimp
    discord
    firefox
    spotify
    obsidian
    pavucontrol
    slack
    google-chrome
    zathura
    wally-cli
    vlc
    signal-desktop
    # qalculate-gtk
    nasc
    _1password-gui
    obs-studio
    blueberry
    calendar-cli
    vdirsyncer
    khal
    evince
    xournalpp
    sxiv
    playerctl
    doctl
    pdfarranger
    zoom-us
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
  };

  xdg.enable = true;

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications =
  {
    "x-scheme-handler/http"  = [ "google-chrome.desktop"];
    "x-scheme-handler/https" = [ "google-chrome.desktop"];
    "text/html"              = [ "google-chrome.desktop"];
  };

  # Manually install gnome meeting applet
  # flatpak install flathub com.chmouel.gnomeNextMeetingApplet
  # run: flatpak run com.chmouel.gnomeNextMeetingApplet

  home.file = {
    ".config/sway/config".source = sway/config;
    ".config/mako/config".source = mako/config;
    ".config/waybar/config".source = waybar/config;
    ".config/waybar/style.css".source = waybar/style.css;
    ".config/polybar-scripts/player-mpris-simple.sh".source = waybar/polybar/player-mpris-simple.sh;
  };

  home.shellAliases = {
    v = "neovide";
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
  ];
}

