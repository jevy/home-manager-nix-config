# Desktop applications (Linux)
{ ... }:
{
  flake.modules.homeManager.desktopApps =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [
        libreoffice
        gimp
        discord
        obsidian
        pavucontrol
        slack
        # google-chrome
        zathura
        keymapp
        vlc
        signal-desktop
        # nasc # Broken?
        blueberry
        # calendar-cli
        vdirsyncer
        # khal
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
        (kooha.overrideAttrs (old: {
          preFixup = (old.preFixup or "") + ''
            gappsWrapperArgs+=(--prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0")
            gappsWrapperArgs+=(--prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${gst_all_1.gst-vaapi}/lib/gstreamer-1.0")
          '';
        }))
        wl-clipboard

        simple-scan
        dragon-drop # Ranger drag drop
        xdg-utils
        ocrmypdf
        via
        qmk
        audacity
        # gnome3.gnome-tweaks
        nvd
        pulseaudio
        alsa-utils
        velero
        restic
        masterpdfeditor
        gparted
        wl-kbptr
        keybase-gui
        chromedriver
        ollama
        docker-compose
        diff-pdf
        numbat
        pdftk
        ddcutil
        ddcui
        psst
        repomix
        nethogs
        marktext
        wl-screenrec
        hyprpicker
        hyprland-monitor-attached
      ];

      services.wlsunset = {
        enable = true;
        latitude = "45.42";
        longitude = "-75.69";
        systemdTarget = "hyprland-session.target";
      };

      programs.spotify-player.enable = true;

      programs.go.enable = true;
      programs.java.enable = true;
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      programs.qutebrowser.enable = true;

      programs.rofi = {
        enable = true;
        # package = pkgs.rofi-wayland.override { plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu]; };
        plugins = [
          pkgs.rofi-emoji
          pkgs.rofi-calc
          pkgs.rofi-power-menu
        ];
      };

      xdg.enable = true;
      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
      };
      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications = {
        "application/pdf" = [ "zathura.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "text/html" = [ "firefox.desktop" ];
      };

      home.pointerCursor = {
        gtk.enable = true;
        hyprcursor.enable = true;
        package = pkgs.vanilla-dmz;
        name = "Vanilla-DMZ";
      };

      programs.vscode = {
        enable = true;
        package = pkgs.vscode.fhs;
      };

      programs.obs-studio = {
        enable = true;
        plugins = [
          pkgs.obs-studio-plugins.obs-pipewire-audio-capture
          pkgs.obs-studio-plugins.obs-backgroundremoval
        ];
      };

      programs.firefox = {
        enable = true;
        profiles.default = { };
      };

      programs.spicetify = {
        enable = true;
      };

      stylix.targets = {
        firefox = {
          enable = false;
          profileNames = [ "default" ];
        };
        vscode = {
          enable = false;
        };
      };

      services.keybase.enable = true;

      programs.neovide = {
        enable = true;
        settings = {
          theme = "auto";
        };
      };

      programs.chromium.enable = true; # qtwebengine takes a really long time

      home.sessionPath = [ "$HOME/bin" ];
      home.file = {
        ".config/mako/config".source = ../../mako/config;
        ".config/waybar/config".source = ../../waybar/config;
        ".config/waybar/style.css".source = ../../waybar/style.css;
        ".config/polybar-scripts/player-mpris-simple.sh".source = ../../waybar/polybar/player-mpris-simple.sh;
        ".config/polybar-scripts/openweathermap-forecast.sh".source =
          ../../waybar/polybar/openweathermap-forecast.sh;
        ".config/backgrounds/".source = ../../backgrounds;
        ".config/zathura/zathurarc".text = "set selection-clipboard clipboard";
        "bin/next-meeting.sh".executable = true;
        "bin/next-meeting.sh".text = ''
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
        screen-record = "${pkgs.wl-screenrec}/bin/wl-screenrec -g \"$(${pkgs.slurp}/bin/slurp)\" --filename=$HOME/Screenshots/latest-recording.mp4";
        screen-record-with-audio = "${pkgs.wl-screenrec}/bin/wl-screenrec --audio -g \"$(${pkgs.slurp}/bin/slurp)\" --filename=$HOME/Screenshots/latest-recording.mp4";
        tailscale-us = "sudo tailscale up --accept-routes --exit-node \"us-tailscale\" --accept-dns";
        tailscale-home = "sudo tailscale up --accept-routes --exit-node \"octoprint\" --accept-dns";
        pomodoro = "termdown 25m -s -b && ${pkgs.libnotify}/bin/notify-send 'Pomodoro complete. Take a break!'";
        s = "kitty +kitten ssh";
        colordropper = "grim -g \"$(slurp -p)\" -t ppm - | convert - -format '%[pixel:p{0,0}]' txt:-";
      };

      # For Flakpak
      xdg.systemDirs.data = [
        "/var/lib/flatpak/exports/share"
      ];
    };
}
