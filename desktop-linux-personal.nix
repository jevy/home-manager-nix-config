{ config, pkgs, libs, ... }:

{
  imports =
  [
    ./desktop-linux-common.nix
  ];

  home.packages = with pkgs; [
    synology-drive-client
    # ruby
    # gnumake
    # gcc
    # bundix
    # # python-qt
    kubernetes-helm
    dropbox
    # arduino
    hugo
    steam
    # ansible
    gcalcli
    # # etcher

    unstable.prusa-slicer
    rpi-imager
    sunpaper
    newsflash
    qflipper
    jellyfin-media-player
    zotero
    unstable.openscad
    eww-wayland
    qgis
    ledfx
  ];

  wayland.windowManager.sway = {
    config = {
      startup = [
        { command = "${pkgs.synology-drive-client}/bin/synology-drive"; }
      ];
    };

  };
}
