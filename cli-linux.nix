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
    btop
  ];

  programs.kitty = {
    enable = true;
    keybindings = {
      "shift+page_up" = "scroll_page_up";
      "shift+page_down" = "scroll_page_down";
    };
  };
}
