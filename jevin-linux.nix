{
  config,
  pkgs,
  libs,
  inputs,
  ...
}:
{
  home.packages = with pkgs; [
    hyprpaper
    upower
  ];

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = ~/.config/nixpkgs/backgrounds/midevil.png
    wallpaper = ,~/.config/nixpkgs/backgrounds/midevil.png
  '';

  imports = [
    ./home.nix
    #./vim/vim.nix
    ./zsh.nix
    ./cli-linux.nix
    (
      {
        config,
        pkgs,
        inputs,
        ...
      }:
      {
        imports = [
          ./desktop-linux-personal.nix
          ./stylix-common.nix
        ];
        # Pass spicetify-nix to desktop-linux-common.nix
        _module.args = {
          spicetify-nix = inputs.spicetify-nix;
        };
      }
    )
    ./mutt-quickjack.nix
    # ./amateur_radio.nix
    inputs.spicetify-nix.homeManagerModules.spicetify
    # ./theme-personal.nix
    ./hyprland.nix
    ./sway.nix
    ./music-making.nix
  ];

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
      };
      background = pkgs.lib.mkForce [
        {
          path = "~/.config/nixpkgs/backgrounds/midevil.png";
          blur_passes = 3;
          blur_size = 8;
        }
      ];
      input-field = pkgs.lib.mkForce [
        {
          position = "0, -80";
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 120;
          on-timeout = "pidof hyprlock || hyprlock";
        }
        {
          timeout = 180;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  services.playerctld.enable = true;

  programs.ashell = {
    enable = true;
    systemd.enable = true;
    systemd.target = "hyprland-session.target";
    settings = {
      modules = {
        left = [ "Workspaces" ];
        center = [ ];
        right = [
          "CustomWeather"
          "MediaPlayer"
          "Tray"
          [
            "Clock"
            "Volume"
            "Privacy"
            "Settings"
          ]
        ];
      };
      clock = {
        format = "%a %d %b %l:%M %p";
      };
      CustomModule = [
        {
          name = "CustomWeather";
          icon = "";
          command = "wget -O - http://wttr.in/.png?m&format=v2 | feh - -Z";
          listen_cmd = "/home/jevin/.config/nixpkgs/waybar/polybar/ashell-weather.sh";
        }
      ];
      workspaces.visibility_mode = "MonitorSpecific";
    };
  };

  systemd.user.services.ashell = {
    Unit = {
      BindsTo = [ "hyprland-session.target" ];
      PartOf = [
        "hyprland-session.target"
        "graphical-session.target"
      ];
      After = [ "hyprland-session.target" ];
    };
    Service = {
      RestartSec = "2s";
    };
  };

  home.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
