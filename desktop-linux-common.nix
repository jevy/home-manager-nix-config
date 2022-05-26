{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    libreoffice
    neovide
    gimp
    discord
    firefox
    spotify
    obsidian
    pavucontrol
    slack
    google-chrome
    zathura
    wally-cli
    vlc
    signal-desktop
    qalculate-gtk
    nasc
    _1password-gui
    obs-studio
    blueberry
    calendar-cli
    vdirsyncer
    khal
    evince
    xournalpp
    sxiv
    playerctl
    gcalcli
    doctl
    pdfarranger
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
  };

  xdg.enable = true;

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications =
  {
    "x-scheme-handler/http"  = [ "google-chrome.desktop"];
    "x-scheme-handler/https" = [ "google-chrome.desktop"];
    "text/html"              = [ "google-chrome.desktop"];
  };

  # TODO: Add all the packages from configuration.nix
  programs.firefox.enable = true;
  wayland.windowManager.sway = {
    enable = true;
    swaynag.enable = true;
    config = {
      assigns = {
        "8" =  [ { class = "Slack";   }];
        "10" = [ { class = "Spotify"; }];
      };

      modifier = "Mod4";
      menu = ${pkgs.rofi}/bin/rofi;

      startup = [
        { command = "slack"; }
        { command = "spotify"; }
        { command = "copyq"; }
      ]

      terminal = "kitty"
      window.border = 5;

      # TODO: Finish outputs
      # output = {
      #   "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344" = 
      #   [ { pos = "2570 1440"; }
      #     { resolution = "3440x1440"; } 
      #     { scale = "1"; }
      #   ];
      #   "Unknown 0x5A2D 0x00000000" pos 3710 2880 resolution 1920x1080 scale 1
      #   "Unknown HP Z27 CN49020L9R" pos 6010 1440 resolution 1920x1200 scale 1 transform 270
      # };

      # TODO: WorkspaceOutputAssign

      # TODO: Finish the keybindings
      # keybindings = {
      #   let
      #     modifier = config.wayland.windowManager.sway.config.modifier;
      #   in lib.mkOptionDefault {
      #     "${modifier}+Return" = "exec ${pkgs.rxvt-unicode-unwrapped}/bin/urxvt";
      #     "${modifier}+Shift+q" = "kill";
      #     "${modifier}+d" = "exec ${pkgs.dmenu}/bin/dmenu_path | ${pkgs.dmenu}/bin/dmenu | ${pkgs.findutils}/bin/xargs swaymsg exec --";
      #   }
      # };



    };

  };

  home.file = {
    ".config/sway/config".source = sway/config;
    ".config/mako/config".source = mako/config;
    ".config/waybar/config".source = waybar/config;
    ".config/waybar/style.css".source = waybar/style.css;
    ".config/polybar-scripts/player-mpris-simple.sh".source = waybar/polybar/player-mpris-simple.sh;
  };

  home.shellAliases = {
    v = "neovide";
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
  ];
}

