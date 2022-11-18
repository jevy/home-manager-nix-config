{ config, pkgs, libs, ... }:

{
  imports =
  [
    ./cli-common.nix
  ];

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
    xsv
    bashmount
  ];

  programs.kitty = {
    enable = true;
    keybindings = {
      "shift+page_up" = "scroll_page_up";
      "shift+page_down" = "scroll_page_down";
    };
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      visual_bell_duration = "0.1";
    };
  };
}
