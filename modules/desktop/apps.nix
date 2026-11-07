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
        # AnyTone AT-D878UV codeplugs: qdmr GUI + dmrconf CLI (YAML read/write
        # over /dev/ttyACM0; dialout group is enough, no udev rule needed).
        # Codeplug + backups live in ~/radio/anytone-868 (git).
        qdmr
        # `d878 write` - ALWAYS write through this, never bare `dmrconf write`:
        # it passes --auto-enable-gps, without which a write turns GPS off and
        # the APRS beacon stops. See pkgs/d878.
        (callPackage ../../pkgs/d878 { })
        # Live IC-7300 meters from shop-sdr's wfview (:4532), for watching
        # WSJT-X Tune / TX without the wfview client (which fights WSJT-X
        # over the dial frequency). Ctrl-C to stop. Levels are hamlib's 0..1
        # scale: Po and Set ×100 ≈ watts; ALC keep near 0 (any reading means
        # overdriven, lower WSJT-X's Pwr slider); SWR is the ratio.
        (writeShellScriptBin "ic7300-meter" ''
          while :; do
            mapfile -t v < <(${hamlib_4}/bin/rigctl -m 2 -r shop-sdr:4532 \
              t l RFPOWER l RFPOWER_METER l ALC l SWR l STRENGTH 2>/dev/null)
            [ "''${#v[@]}" -ge 6 ] || { printf '\r%-70s' "no answer from shop-sdr:4532"; sleep 2; continue; }
            if [ "''${v[0]}" = 1 ]; then st="TX"; else st="rx"; fi
            LC_ALL=C printf '\r%s  set %3.0f W  Po %3.0f W  ALC %4.2f  SWR %4.2f  S %+3d dB   ' \
              "$st" "$(echo "''${v[1]}*100" | ${bc}/bin/bc -l)" "$(echo "''${v[2]}*100" | ${bc}/bin/bc -l)" \
              "''${v[3]}" "''${v[4]}" "''${v[5]}"
            sleep 0.5
          done
        '')
        wfview      # remote IC-7300 (SSB, waterfall) via shop-sdr's wfview server
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
        enable = true;
        gtk.enable = true;
        hyprcursor.enable = true;
        package = pkgs.vanilla-dmz;
        name = "Vanilla-DMZ";
      };

      programs.obs-studio = {
        enable = true;
        plugins = [
          pkgs.obs-studio-plugins.obs-pipewire-audio-capture
          pkgs.obs-studio-plugins.obs-backgroundremoval
          # ISO recording: adds a "Source Record" filter that writes any one
          # source to its own file alongside the main canvas recording, so the
          # camera and the screen land as separate clips to composite in the
          # edit. Set each filter's encoder to VAAPI so the iGPU carries them
          # and x264 keeps the program recording to itself.
          pkgs.obs-studio-plugins.obs-source-record
        ];
      };

      programs.firefox = {
        enable = true;
        configPath = ".mozilla/firefox";
        # Websites always get prefers-color-scheme: light (0 dark, 1 light,
        # 2 follow the system). Following the system isn't enough: Noctalia
        # runs `gsettings set ... color-scheme prefer-dark` on every start and
        # theme change while its theme.mode is "dark" (desktop/noctalia.nix),
        # overwriting the prefer-light set below.
        profiles.default.settings."layout.css.prefers-color-scheme.content-override" = 1;
      };

      programs.spicetify = {
        enable = true;
      };

      stylix.targets = {
        firefox = {
          enable = false;
          profileNames = [ "default" ];
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

        # Ham radio — IC-7300 remote control via shop-sdr
        ic7300 = "ssh shop-sdr sudo systemctl stop wsjtx-wspr; ssh -YC shop-sdr wsjtx-ic7300; ssh shop-sdr sudo systemctl start wsjtx-wspr";
        # First run: Settings > Radio Access > Network: host shop-sdr, jevin / shop.
        # Also tick "Manual Radio CI-V Address" = 94 + "Use CI-V address as Model":
        # on auto-detect the client never gets rigCaps over the server and stays
        # greyed out ("NONE"), reconnecting every 60 s.
        # Each of these stops the WSPR beacon first: it holds the 7300's audio
        # and PTT. ic7300-wspr hands the radio back to the beacon.
        ic7300-ssb = "ssh shop-sdr sudo systemctl stop wsjtx-wspr; setsid -f wfview";
        ic7300-wspr = "ssh shop-sdr sudo systemctl start wsjtx-wspr";
        # JS8Call on shop-sdr over X forwarding; its settings (VA3JEV, Hamlib
        # NET rigctl localhost:4532 = wfview, PTT CAT, PCM2901 audio,
        # PSKReporter on) live in shop-sdr:~/.config/JS8Call.ini. Pauses the
        # beacon while it runs and hands the radio back when you quit.
        # 40m JS8 is 7.078 USB; who heard you: pskreporter.info, mode JS8.
        ic7300-js8 = "ssh shop-sdr sudo systemctl stop wsjtx-wspr; ssh -YC shop-sdr 'QT_SCALE_FACTOR=2 QT_XCB_GL_INTEGRATION=none js8call'; ssh shop-sdr sudo systemctl start wsjtx-wspr";
        ic7300-rigctl = "rigctl -m 2 -r shop-sdr:4532";
        # Live map of what WSJT-X decodes: GridTracker on shop-sdr, over X
        # forwarding. Run alongside `ic7300`; it takes WSJT-X's UDP 2237.
        # The UPower and "WebGL1 blocklisted" errors it prints are harmless
        # (no battery service, no GPU over X forwarding). Who heard *you* is
        # pskreporter.info/pskmap.html?callsign=VA3JEV instead.
        ic7300-map = "ssh -YC shop-sdr gridtracker 2>/dev/null";
        # Listen only: plays shop-sdr's ic7300-rx (radio RX audio) here over
        # pulse TCP :4713. No TX and no need to stop the beacon (you will hear
        # WSPR/FT8 tones). Ctrl-C to stop.
        ic7300-listen = "parec --server=shop-sdr -d ic7300-rx --format=s16le --rate=12000 --channels=1 --latency-msec=200 | pacat --format=s16le --rate=12000 --channels=1";
        pomodoro = "termdown 25m -s -b && ${pkgs.libnotify}/bin/notify-send 'Pomodoro complete. Take a break!'";
        sb = ''cd "${config.secondBrain.basePath}"'';
        s = "kitty +kitten ssh";
        colordropper = "grim -g \"$(slurp -p)\" -t ppm - | convert - -format '%[pixel:p{0,0}]' txt:-";
      };
    };
}
