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

    prusa-slicer
    rpi-imager
    element-desktop-wayland
    # unstable.sunpaper
  ];

  programs.sunpaper = {
    enable = true;
    latitude = 45.42;
    longitude = -75.70;
  };

}
