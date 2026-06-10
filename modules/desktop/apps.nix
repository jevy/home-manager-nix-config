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
        blueman
        solaar
        # calendar-cli
        vdirsyncer
        # khal
        evince
        xournalpp
        imv
        playerctl
        doctl
        pdfarranger
        zoom-us
        cht-sh
        cheat
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

        simple-scan
        ripdrag # Ranger drag drop
        xdg-utils
        ocrmypdf
        (symlinkJoin {
          name = "via";
          paths = [ via ];
          nativeBuildInputs = [ makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/via --add-flags "--force-device-scale-factor=1"
          '';
        })
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
        # ollama  # replaced by llama-swap + llama.cpp
        docker-compose
        diff-pdf
        numbat
        pdftk
        ddcutil
        ddcui
        rnote
        papers
        repomix
        nethogs
        wl-screenrec
        hyprpicker
        hyprland-monitor-attached

        # Ham radio rig control
        flrig
        hamlib_4
        grig
        tigervnc
        remmina
        xauth
        gridtracker
      ];

      services.wlsunset = {
        enable = true;
        latitude = "45.42";
        longitude = "-75.69";
        temperature.night = 2800;
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


      xdg.enable = true;
      xdg.portal = {
        enable = true;
        extraPortals = [
          pkgs.xdg-desktop-portal-hyprland
          pkgs.xdg-desktop-portal-gtk
        ];
        # NOTE: on the lenovo-p14s, the CVE-2026-46333 kernel ptrace hardening
        # breaks this portal's app-info resolution, killing every file-picker and
        # screen-share popup. The fix (grant the portal CAP_SYS_PTRACE via a
        # security.wrappers shim + service drop-in) lives in
        # modules/hardware/lenovo-p14s.nix — security.wrappers is NixOS-only and
        # can't live in this home-manager module.
      };
      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "text/html" = [ "firefox.desktop" ];
        "image/png" = [ "imv.desktop" ];
        "image/jpeg" = [ "imv.desktop" ];
        "image/gif" = [ "imv.desktop" ];
        "image/webp" = [ "imv.desktop" ];
        "image/bmp" = [ "imv.desktop" ];
        "image/svg+xml" = [ "imv.desktop" ];
        "text/plain" = [ "neovide.desktop" ];
        "application/toml" = [ "neovide.desktop" ];
        "application/json" = [ "neovide.desktop" ];
        "application/yaml" = [ "neovide.desktop" ];
        "application/x-shellscript" = [ "neovide.desktop" ];
        "text/markdown" = [ "neovide.desktop" ];
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
        configPath = ".mozilla/firefox";
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
        # Stylix's GTK target overlays dark gruvbox values onto libadwaita's
        # named color tokens (window_bg_color, view_bg_color, …), which makes
        # every GTK4/libadwaita app — and any Electron/Firefox app inferring
        # system appearance from the GTK palette — render dark. Disable it so
        # those apps follow adw-gtk3 light below.
        gtk.enable = false;
        gnome.enable = false;
      };

      gtk = {
        enable = true;
        theme = {
          name = "adw-gtk3";
          package = pkgs.adw-gtk3;
        };
        gtk4.theme = config.gtk.theme;
        iconTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
      };

      # Tell xdg-desktop-portal (and thus Electron apps like Slack, plus
      # Firefox's prefers-color-scheme) that the system prefers light.
      dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-light";

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
        v = "setsid -f ${pkgs.neovide}/bin/neovide";
        screen-record = "${pkgs.wl-screenrec}/bin/wl-screenrec -g \"$(${pkgs.slurp}/bin/slurp)\" --filename=$HOME/Screenshots/latest-recording.mp4";
        screen-record-with-audio = "${pkgs.wl-screenrec}/bin/wl-screenrec --audio -g \"$(${pkgs.slurp}/bin/slurp)\" --filename=$HOME/Screenshots/latest-recording.mp4";
        tailscale-us = "sudo tailscale up --accept-routes --exit-node \"us-tailscale\" --accept-dns";
        tailscale-home = "sudo tailscale up --accept-routes --exit-node \"octoprint\" --accept-dns";

        # Ham radio — IC-7300 remote control via shop-sdr
        ic7300 = "ssh shop-sdr 'sudo systemctl stop wsjtx-wspr 2>/dev/null; sudo rm -rf /tmp/WSJT-X /tmp/WSJT-X.lock /tmp/qipc_sharedmemory_* /tmp/qipc_systemsem_*; sudo ipcrm --all=shm 2>/dev/null; mkdir -p /tmp/WSJT-X'; ssh -YC shop-sdr 'QT_SCALE_FACTOR=2 QT_XCB_GL_INTEGRATION=none wsjtx'";
        ic7300-headless = "ssh shop-sdr sudo systemctl start wsjtx-wspr";
        ic7300-vnc = "vncviewer -FullScreen shop-sdr:5942";
        ic7300-rigctl = "rigctl -m 2 -r shop-sdr:4532";
        pomodoro = "termdown 25m -s -b && ${pkgs.libnotify}/bin/notify-send 'Pomodoro complete. Take a break!'";
        sb = ''cd "${config.secondBrain.basePath}"'';
        s = "kitty +kitten ssh";
        colordropper = "grim -g \"$(slurp -p)\" -t ppm - | convert - -format '%[pixel:p{0,0}]' txt:-";
      };

      # For Flakpak
      xdg.systemDirs.data = [
        "/var/lib/flatpak/exports/share"
      ];
    };
}
