{ config, pkgs, ... }:
{

  home.packages = with pkgs; [
    libreoffice
    neovide
    gimp
    unstable.discord
    unstable.spotify
    unstable.obsidian
    pavucontrol
    slack
    # google-chrome
    zathura
    wally-cli
    vlc
    unstable.signal-desktop
    # nasc # Broken?
    blueberry
    # calendar-cli
    vdirsyncer
    # khal
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
    # gnome3.gnome-tweaks
    nvd
    pulseaudio
    swayidle
    swaylock
    alsa-utils
    unstable.lens
    velero
    restic
    masterpdfeditor
    gparted
    warpd
    keybase-gui
    chromedriver
    bottles
    unstable.ollama
    docker-compose
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
  programs.direnv.enable = true;

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland.override { plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu]; };
    # plugins = [ pkgs.rofi-emoji pkgs.rofi-calc pkgs.rofi-power-menu ];
  };

  xdg.enable = true;
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications =
  {
    "application/pdf" = [ "zathura.desktop"];
    "x-scheme-handler/http"  = [ "firefox.desktop"];
    "x-scheme-handler/https" = [ "firefox.desktop"];
    "text/html"              = [ "firefox.desktop"];
  };

  # home.pointerCursor = {
  #   package = pkgs.nordzy-cursor-theme;
  #   gtk.enable = true;
  #   name = "Nordzy-cursors";
  # };


  programs.obs-studio = {
    enable = true;
    plugins = [ 
      pkgs.obs-studio-plugins.wlrobs 
      pkgs.obs-studio-plugins.obs-pipewire-audio-capture
      pkgs.obs-studio-plugins.obs-backgroundremoval
    ];
  };

  programs.firefox = {
    enable = true;
  };

  services.keybase.enable = true;

  programs.chromium.enable = true;
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # For Wayland Chrome and Electron
  };

  # dconf.settings = {
  #   "org/gnome/mutter" = {
  #     experimental-features = [ "scale-monitor-framebuffer" ];
  #   };
  # };

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
    colordropper = "grim -g \"$(slurp -p)\" -t ppm - | convert - -format '%[pixel:p{0,0}]' txt:-";
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/var/lib/flatpak/exports/share"
  ];
}
