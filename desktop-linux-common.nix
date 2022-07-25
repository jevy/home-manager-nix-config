{ config, pkgs, libs, lib, ... }:
{

  home.packages = with pkgs; [
    libreoffice
    neovide
    neovim-remote
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
    # qalculate-gtk
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
    doctl
    pdfarranger
    zoom-us
    cht-sh
    cheat
    jdk11 # For kafka cp-demo
    openssl # For kafka cp-demo
    xdg-desktop-portal-wlr
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
  };

  xdg.enable = true;

  programs.rofi = {
    enable = true;
    package = pkgs.rofi.override { plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu]; };
    plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu ];
  };

  services.swayidle.enable = true;
  services.swayidle.events = [
    { event = "before-sleep"; command = "${pkgs.swaylock-effects}/bin/swaylock"; }
    { event = "lock"; command = "lock"; }
  ];
  services.swayidle.timeouts = [
    { timeout = 400; command = "${pkgs.swaylock-effects}/bin/swaylock"; }
  ];

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

      bars = [
        { command = "${config.programs.waybar.package}/bin/waybar"; }
      ];

      assigns = {
        "8" =  [ { class = "Slack";   }];
        "10" = [ { class = "Spotify"; }];
      };

      modifier = "Mod4";
      menu = "rofi -show run";

      startup = [
        { command = "${pkgs.slack}/bin/slack"; }
        { command = "${pkgs.spotify}/bin/spotify"; }
        { command = "${pkgs.flashfocus}/bin/flashfocus"; }
        { command = "${pkgs._1password-gui}/bin/1password"; }
      ];

      terminal = "kitty";

      window = {
        border = 5;
        titlebar = true;
      };

      # TODO: Finish outputs
      output = {
        "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344" =
          { pos = "2570 1440";
            resolution = "3440x1440";
            scale = "1";
          };
        "Unknown 0x5A2D 0x00000000" =
          { pos = "3710 2880";
            resolution = "1920x1080";
            scale = "1";
          };
        "Unknown HP Z27 CN49020L9R" =
          { pos = "6010 1440";
            resolution = "1920x1200";
            scale = "1";
            transform = "270";
          };
      };

      workspaceOutputAssign =
        let
          primary-output   = "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344";
          secondary-output = "Unknown 0x5A2D 0x00000000";
          side-output      = "Unknown HP Z27 CN49020L9R";
        in
        [
          { workspace = "1"; output = "${primary-output} ${secondary-output}"; }
          { workspace = "2"; output = "${primary-output} ${secondary-output}"; }
          { workspace = "3"; output = "${primary-output} ${secondary-output}"; }
          { workspace = "4"; output = "${primary-output} ${secondary-output}"; }
          { workspace = "5"; output = "${primary-output} ${secondary-output}"; }
          { workspace = "6"; output = "${side-output} ${secondary-output}";    }
          { workspace = "7"; output = "${secondary-output} ${primary-output}"; }
          { workspace = "8"; output = "${secondary-output} ${primary-output}"; }
          { workspace = "9"; output = "${secondary-output} ${primary-output}"; }
          { workspace = "0"; output = "${secondary-output} ${primary-output}"; }
        ];

      keybindings =
        let
          modifier = config.wayland.windowManager.sway.config.modifier;
        in lib.mkOptionDefault {
          "${modifier}+Shift+q" = "kill";
          "${modifier}+Shift+r" = "reload";

          "${modifier}+Control+Shift+l" = "move workspace to output right";
          "${modifier}+Control+Shift+h" = "move workspace to output left";
          "${modifier}+Control+Shift+j" = "move workspace to output down";
          "${modifier}+Control+Shift+k" = "move workspace to output up";

          # There isn't a 10th workspace by default
          "${modifier}+0" = "workspace 10";
          "${modifier}+Shift+0" = "move container to workspace 10";

          # Launch programs
          # TODO: Pull over working rofi config
          "${modifier}+c" = "exec rofi -show calc";
          "${modifier}+u" = "exec ${pkgs.firefox}/bin/firefox";
          "${modifier}+t" = "exec kitty -- ${pkgs.ranger}/bin/ranger ~/Downloads";
          "${modifier}+i" = "exec ${pkgs.blueberry}/bin/blueberry";

          # Controls
          "XF86AudioMute"        = "exec ${pkgs.pamixer}/bin/pamixer -t";
          "XF86AudioMicMute"     = "exec ${pkgs.pamixer}/bin/pamixer --default-source -t";
          "XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer -d 10";
          "XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer -i 10";
          "Print" = "exec /usr/bin/env bash | grim -g \"$(slurp)\" - | swappy -f -";
          "${modifier}+n" = "exec ${pkgs.mako}/bin/makoctl dismiss";
        };

      keycodebindings = {
        "164" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
        "232" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
        "233" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
      };

      input = {
        "*" = {
          xkb_options = "ctrl:nocaps";
        };
        "1133:45088:MX_Vertical_Mouse" = {
            accel_profile = "flat";
            pointer_accel = "-0.2";
        };
      };

    };

  };

  home.file = {
    ".config/mako/config".source = mako/config;
    ".config/waybar/config".source = waybar/config;
    ".config/waybar/style.css".source = waybar/style.css;
    ".config/polybar-scripts/player-mpris-simple.sh".source = waybar/polybar/player-mpris-simple.sh;
    ".config/backgrounds/".source = ./backgrounds;
  };

  home.shellAliases = {
    v = "${pkgs.neovide}/bin/neovide";
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
  ];
}

