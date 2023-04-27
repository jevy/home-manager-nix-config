{ config, pkgs, libs, lib, ... }:
{

  home.packages = with pkgs; [
    libreoffice
    neovide
    neovim-remote
    gimp
    unstable.discord
    firefox-wayland
    unstable.spotify
    unstable.obsidian
    pavucontrol
    slack
    google-chrome
    zathura
    wally-cli
    vlc
    unstable.signal-desktop
    # qalculate-gtk
    # nasc # Broken?
    blueberry
    calendar-cli
    vdirsyncer
    khal
    evince
    unstable.xournalpp
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
    wl-clipboard
    wf-recorder
    jq
    gnome.simple-scan
    xdragon # Ranger drag drop
    xdg-utils
    ocrmypdf
    unstable.via
    qmk
    audacity
    spotify-tui
    gnome3.gnome-tweaks
    nvd
    pulseaudio
    swayidle
    swaylock
    alsa-utils
  ];

  services.wlsunset = {
    enable = true;
    latitude = "45.42";
    longitude = "-75.69";
    systemdTarget = "sway-session.target";
  };

  # services.mpris-proxy.enable = true;

  programs.go.enable = true;
  programs.java.enable = true;

  programs.rofi = {
    enable = true;
    package = pkgs.rofi.override { plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu]; };
    plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu ];
  };

  xdg.enable = true;
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications =
  {
    "application/pdf" = [ "zathura.desktop"];
    # "x-scheme-handler/http"  = [ "firefox.desktop"];
    # "x-scheme-handler/https" = [ "firefox.desktop"];
    # "text/html"              = [ "firefox.desktop"];
  };

  home.pointerCursor = {
    package = pkgs.nordzy-cursor-theme;
    gtk.enable = true;
    name = "Nordzy-cursors";
  };


  programs.obs-studio = {
    enable = true;
    plugins = [ pkgs.obs-studio-plugins.wlrobs ];
  };

  wayland.windowManager.sway = {
    enable = true;
    swaynag.enable = true;

    config = {

      bars = [
        { command = "${config.programs.waybar.package}/bin/waybar"; }
      ];

      gaps = {
        smartBorders = "on";
      };

      assigns = {
        "8" =  [ { class = "Slack";   }];
        "10" = [ { class = "Spotify"; }];
      };

      modifier = "Mod4";
      menu = "rofi -show run";
      workspaceAutoBackAndForth = true;

      startup =
        [
        { command = "${pkgs.slack}/bin/slack"; }
        { command = "spotify"; }
        { command = "${pkgs.flashfocus}/bin/flashfocus"; }
        { command = "${pkgs.unstable._1password-gui}/bin/1password"; }
        { command = "swayidle -w timeout 300 'swaylock -f -c 00a00a' timeout 600 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"' before-sleep 'swaylock -f -c 000000'" ;}
        ];

      terminal = "kitty";

      window = {
        border = 5;
        titlebar = true;
        commands = [
          # From: https://www.reddit.com/r/swaywm/comments/conhod/inhibit_idle_while_a_fullscreen_app_is_running/
          { command = "inhibit_idle fullscreen"; criteria = { class  = "^.*"; } ; }
          { command = "inhibit_idle fullscreen"; criteria = { app_id = "^.*"; } ; }

          # Zoom floating
          { command = "floating enable";  criteria = { app_id = "zoom"; } ; }
          { command = "floating enable";  criteria = { app_id = "zoom"; title = "Choose ONE of the audio conference options";} ; }
          { command = "floating enable";  criteria = { app_id = "zoom"; title = "zoom";} ; }
          { command = "floating enable";  criteria = { title = "Zoom Cloud Meetings";} ; }
          { command = "floating disable"; criteria = { app_id = "zoom"; title = "Zoom Meeting";} ; }
          { command = "floating disable"; criteria = { app_id = "zoom"; title = "Zoom - Free Account";} ; }

          { command = "floating enable";  criteria = { app_id = "firefox"; title = "Firefox — Sharing Indicator";} ; }
        ];
      };

      # TODO: Finish outputs
      output = {
        "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344" =
          { pos = "2570 1440";
            resolution = "3440x1440";
            scale = "1";
          };
        # Lenovo
        "Unknown 0x5A2D 0x00000000" =
          { pos = "3710 2880";
            resolution = "1920x1080";
            scale = "1";
          };
        # Framework
        "Unknown 0x095F 0x00000000" =
          { pos = "3710 2880";
            resolution = "2256x1504";
            scale = "1.5";
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
          "${modifier}+u" = "exec firefox";
          "${modifier}+t" = "exec kitty -- ${pkgs.ranger}/bin/ranger ~/Downloads";
          "${modifier}+i" = "exec ${pkgs.blueberry}/bin/blueberry";
          "${modifier}+o" = "exec ${pkgs.rofi-bluetooth}/bin/rofi-bluetooth";
          "${modifier}+p" = "exec ${pkgs.swaylock}/bin/swaylock -f -c 000088";

          # Controls
          "XF86AudioMute"        = "exec ${pkgs.pamixer}/bin/pamixer -t";
          "XF86AudioMicMute"     = "exec ${pkgs.pamixer}/bin/pamixer --default-source -t";
          "XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer -d 10";
          "XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer -i 10";
          "XF86AudioPlay"        = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
          "XF86AudioNext"        = "exec ${pkgs.playerctl}/bin/playerctl next";
          "XF86AudioPrev"        = "exec ${pkgs.playerctl}/bin/playerctl previous";
          "Print"                = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.swappy}/bin/swappy -f -";
          "${modifier}+n"        = "exec ${pkgs.mako}/bin/makoctl dismiss";
          "XF86Tools"            = "exec ${pkgs.spotify-tui}/bin/spt pb -v $(($(${pkgs.spotify-tui}/bin/spt pb -f %v)-20)) "; # F13 for macropad
          "XF86Launch5"          = "exec ${pkgs.spotify-tui}/bin/spt pb -v $(($(${pkgs.spotify-tui}/bin/spt pb -f %v)+20)) "; # F14 for macropad
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

  home.sessionPath = [ "$HOME/bin" ];
  home.file = {
    ".config/mako/config".source                                = mako/config;
    ".config/waybar/config".source                              = waybar/config;
    ".config/waybar/style.css".source                           = waybar/style.css;
    ".config/polybar-scripts/player-mpris-simple.sh".source     = waybar/polybar/player-mpris-simple.sh;
    ".config/polybar-scripts/openweathermap-forecast.sh".source = waybar/polybar/openweathermap-forecast.sh;
    ".config/backgrounds/".source                               = ./backgrounds;
    ".config/zathura/zathurarc".text                            = "set selection-clipboard clipboard";
    "bin/next-meeting.sh".executable                            = true;
    "bin/next-meeting.sh".text                                  = ''
      #!/usr/bin/env bash
      gcalcli agenda --nocolor --nostarted `date +%H:%M` `date -d '+1 hour' +%H:%M` | sed 's/\x1B\[\([0-9]\{1,2\}\(;[0-9]\{1,2\}\)\?\)\?[mGK]//g' | sed '/No title/d' | sed 's/  */ /g' | sed '/^$/d' | head -1 | cut -f 4- -d ' ' | cut -c -30
      '';
  };


  xdg.configFile."swappy/config" = {
    text = ''
      [Default]
      save_dir=~/Screenshots
      save_filename_format=swappy-%Y%m%d-%H%M%S.png
      early_exit=true
    '';
  };

  # From https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/audio/alsa.nix#L101
  systemd.user.services = {
    alsa-store = {
      Unit = {
        Description = "Store Sound Card State";
        RequiresMountsFor = "${config.xdg.configHome}/.config/alsa";
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.alsa-utils}/sbin/alsactl restore -f ${config.xdg.configHome}/alsa/asound.state";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

  };

  home.shellAliases = {
    v = "${pkgs.neovide}/bin/neovide";
    screen-record = "${pkgs.wf-recorder}/bin/wf-recorder -g \"$(${pkgs.slurp}/bin/slurp)\" --file=$HOME/Screenshots/latest-recording.mp4";
    screen-record-with-audio = "${pkgs.wf-recorder}/bin/wf-recorder -a -g \"$(${pkgs.slurp}/bin/slurp)\" --file=$HOME/Screenshots/latest-recording.mp4";
    tailscale-us = "sudo tailscale up --accept-routes --exit-node \"us-tailscale\" --accept-dns";
    tailscale-home = "sudo tailscale up --accept-routes --exit-node \"octoprint\" --accept-dns";
    pomodoro = "termdown 25m -s -b && ${pkgs.libnotify}/bin/notify-send 'Pomodoro complete. Take a break!'";
    alsafix = "cd ~/.config/alsa && alsactl restore -f asound.state";
    s = "kitty +kitten ssh";
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
  ];
}

