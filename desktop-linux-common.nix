{ config, pkgs, libs, lib, ... }:
{

  home.packages = with pkgs; [
    libreoffice
    neovide
    neovim-remote
    gimp
    discord
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
    mako
    grim
    swappy
    slurp
    brightnessctl
    wdisplays
    kooha
    helvum   # Pipewire
    qpwgraph # Pipewire
    wl-clipboard
    swaylock-effects
    wf-recorder
    jq
    gnome.simple-scan
    xdragon
    etcher
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
  };

  xdg.enable = true;

  programs.java.enable = true;
  programs.rofi = {
    enable = true;
    package = pkgs.rofi.override { plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu]; };
    plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu ];
  };

  services.swayidle = let
    lock_command = "${pkgs.swaylock-effects}/bin/swaylock -f --screenshots --clock --indicator --indicator-radius 100 --indicator-thickness 7 --effect-blur 7x5 --effect-vignette 0.5:0.5 --ring-color bb00cc --key-hl-color 880033 --line-color 00000000 --inside-color 00000088 --separator-color 00000000 --grace 8 --fade-in 0.2" ;
  in { enable = true;
       events = [
         { event = "before-sleep"; command = lock_command; }
         # { event = "lock"; command = "lock"; }
       ];
    timeouts = [
      { timeout = 300; command = lock_command; }
      { timeout = 400; command = "swaymsg 'output * dpms off'"; resumeCommand = "swaymsg 'output * dpms on'"; }
    ];
  };

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications =
  {
    "x-scheme-handler/http"  = [ "google-chrome.desktop"];
    "x-scheme-handler/https" = [ "google-chrome.desktop"];
    "text/html"              = [ "google-chrome.desktop"];
  };

  programs.firefox.enable = true;

  home.pointerCursor = {
    package = pkgs.nordzy-cursor-theme;
    gtk.enable = true;
    name = "Nordzy-cursors";
  };

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
        { command = "${pkgs.unstable._1password-gui}/bin/1password"; }
      ];

      terminal = "kitty";

      window = {
        border = 5;
        titlebar = true;
        commands = [
          # From: https://www.reddit.com/r/swaywm/comments/conhod/inhibit_idle_while_a_fullscreen_app_is_running/
          { command = "inhibit_idle fullscreen"; criteria = { class  = "^.*"; } ; }
          { command = "inhibit_idle fullscreen"; criteria = { app_id = "^.*"; } ; }
        ];
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
          "${modifier}+0"       = "workspace 10";
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
          "Pause"                = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
          "Print"                = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.swappy}/bin/swappy -f -";
          "${modifier}+n"        = "exec ${pkgs.mako}/bin/makoctl dismiss";
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
    ".config/mako/config".source                                = mako/config;
    ".config/waybar/config".source                              = waybar/config;
    ".config/waybar/style.css".source                           = waybar/style.css;
    ".config/polybar-scripts/player-mpris-simple.sh".source     = waybar/polybar/player-mpris-simple.sh;
    ".config/polybar-scripts/openweathermap-forecast.sh".source = waybar/polybar/openweathermap-forecast.sh;
    ".config/backgrounds/".source                               = ./backgrounds;
  };

  xdg.configFile."swappy/config" = {
    text = ''
      [Default]
      save_dir=~/Screenshots
      save_filename_format=swappy-%Y%m%d-%H%M%S.png
      early_exit=true
    '';
  };

  home.shellAliases = {
    v = "${pkgs.neovide}/bin/neovide";
    screen-record = "${pkgs.wf-recorder}/bin/wf-recorder -g \"$(${pkgs.slurp}/bin/slurp)\" --file=$HOME/Screenshots/latest-recording.mp4";
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
  ];
}

