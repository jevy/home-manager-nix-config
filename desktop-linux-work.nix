{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    neovide
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
    qalculate-gtk
    nasc
    _1password-gui
    obs-studio
    blueberry
    calendar-cli
    vdirsyncer
    khal
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
  }

  xdg.enable = true;

  xdg.mimeApps.enable = true;

  # Manually install gnome meeting applet
  # flatpak install flathub com.chmouel.gnomeNextMeetingApplet
  # run: flatpak run com.chmouel.gnomeNextMeetingApplet

  home.file = {
    ".config/sway/config".source = sway/config;
    ".config/mako/config".source = mako/config;
    ".config/waybar/config".source = waybar/config;
    ".config/waybar/style.css".source = waybar/style.css;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
    "/home/jevinhumi/.local/share/flatpak/exports/share"
  ];

}
