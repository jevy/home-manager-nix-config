{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    docker
    docker-compose
    imagemagickBig
    mlocate # For ranger
    awscli2
    usbutils
    kitty
    ripgrep-all
  ];

  home.file = {
    ".config/kitty/kitty.conf".source = kitty/kitty.conf;
  };
}
