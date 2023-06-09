{ config, pkgs, libs, ... }:

{
  imports =
  [
    ./desktop-linux-common.nix
  ];

  home.packages = with pkgs; [
    # synology-drive-client
    # ruby
    # gnumake
    # gcc
    # bundix
    # # python-qt
    # kubernetes-helm
    # dropbox
    # arduino
    # hugo
    # steam
    # ansible
    # gcalcli
    # # etcher

    # prusa-slicer
    # cura
    # rpi-imager
    # element-desktop-wayland
    # # unstable.sunpaper
    # bottles
    # transmission-gtk
    # unstable.newsflash
    # qflipper
    # jellyfin-media-player
    # zotero
    # unstable.openscad
  ];

  # wayland.windowManager.sway = {
  #   config = {
  #     startup = [
  #       { command = "${pkgs.synology-drive-client}/bin/synology-drive"; }
  #     ];
  #   };

  # };
}
