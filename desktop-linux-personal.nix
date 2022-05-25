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
    python-qt
    kubernetes-helm
    dropbox
    arduino
    hugo
    steam
    # cubicsdr
    # sdrangel
    # gqrx
    # sdrpp-with-sdrplay
    # hamlib_4
    # wsjtx
    # unstable.element-desktop-wayland
    # helvum
    ansible_2_10
    etcher

    prusa-slicer
    rpi-imager
  ];

}
