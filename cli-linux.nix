{
  config,
  pkgs,
  libs,
  ...
}: {
  imports = [
    ./cli-common.nix
  ];

  home.packages = with pkgs; [
    imagemagickBig
    mlocate # For ranger
    # awscli2 # Broken Aug 18 2024
    usbutils
    kitty
    ripgrep-all
    btop
    xsv
    bashmount
    ncdu
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
