{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    docker
    docker-compose
    imagemagickBig
    mlocate # For ranger
    awscli2
    usbutils
  ];

}
