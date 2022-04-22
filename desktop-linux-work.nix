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
    gcalcli
    qalculate-gtk
    nasc
    _1password-gui
    obs-studio
    blueberry
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
  }

  home.file = {
    ".config/sway/config".source = sway/config;
    ".config/mako/config".source = mako/config;
  };

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
  };

}
