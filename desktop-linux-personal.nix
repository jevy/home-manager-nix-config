{ config, pkgs, libs, ... }:

{
  imports =
  [
    ./desktop-linux-common.nix
  ];

  home.packages = with pkgs; [
    synology-drive-client
    ruby
    gnumake
    gcc
    bundix
    # python-qt
    kubernetes-helm
    dropbox
    arduino
    hugo
    steam
    ansible
    gcalcli
    # etcher

    unstable.prusa-slicer
    cura
    rpi-imager
    element-desktop-wayland
    # unstable.sunpaper
    bottles
    transmission-gtk
    openscad
  ];

  xdg.mimeApps.defaultApplications =
  {
    "x-scheme-handler/http"  = [ "firefox.desktop"];
    "x-scheme-handler/https" = [ "firefox.desktop"];
    "text/html"              = [ "firefox.desktop"];
  };

  wayland.windowManager.sway = {
    config = {
      startup = [
        { command = "${pkgs.synology-drive-client}/bin/synology-drive"; }
      ];
    };

  };

}
