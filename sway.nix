{
  config,
  pkgs,
  libs,
  lib,
  ...
}: {
  wayland.windowManager.sway = {
    enable = true;
    swaynag.enable = true;
    systemd.enable = true;
    checkConfig = true;
    wrapperFeatures = {
      gtk = true;
    };

    config = {
      bars = [
        {command = "${config.programs.waybar.package}/bin/waybar";}
      ];

      gaps = {
        smartBorders = "on";
      };

      assigns = {
        "8" = [{class = "Slack";}];
        "10" = [{class = "Spotify";}];
      };

      modifier = "Mod4";
      menu = "rofi -modes run -show run";
      workspaceAutoBackAndForth = false;

      startup = [
        {command = "${pkgs.slack}/bin/slack";}
        {command = "spotify";}
        {command = "${pkgs.flashfocus}/bin/flashfocus";}
        {command = "${pkgs.unstable._1password-gui}/bin/1password";}
        {command = "swayidle -w timeout 300 'swaylock -f -c 00a00a' timeout 600 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"' before-sleep 'swaylock -f -c 000000'";}
      ];

      terminal = "ghostty";

      window = {
        border = 5;
        titlebar = true;
        commands = [
          # From: https://www.reddit.com/r/swaywm/comments/conhod/inhibit_idle_while_a_fullscreen_app_is_running/
          {
            command = "inhibit_idle fullscreen";
            criteria = {class = "^.*";};
          }
          {
            command = "inhibit_idle fullscreen";
            criteria = {app_id = "^.*";};
          }

          # Zoom floating
          {
            command = "floating enable";
            criteria = {app_id = "zoom";};
          }
          {
            command = "floating enable";
            criteria = {
              app_id = "zoom";
              title = "Choose ONE of the audio conference options";
            };
          }
          {
            command = "floating enable";
            criteria = {
              app_id = "zoom";
              title = "zoom";
            };
          }
          {
            command = "floating enable";
            criteria = {title = "Zoom Cloud Meetings";};
          }
          {
            command = "floating disable";
            criteria = {
              app_id = "zoom";
              title = "Zoom Meeting";
            };
          }
          {
            command = "floating disable";
            criteria = {
              app_id = "zoom";
              title = "Zoom - Free Account";
            };
          }

          {
            command = "floating enable";
            criteria = {
              app_id = "firefox";
              title = "Firefox — Sharing Indicator";
            };
          }
        ];
      };

      output = {
        "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344" = {
          pos = "2570 1440";
          resolution = "3440x1440";
          scale = "1";
        };
        "LG Electronics LG ULTRAGEAR 106NTLE12344" = {
          pos = "5214 2880";
          resolution = "3440x1440";
          scale = "1";
        };
        # Lenovo
        "Unknown 0x5A2D 0x00000000" = {
          pos = "3710 2880";
          resolution = "1920x1080";
          scale = "1";
        };
        # Framework
        "Unknown 0x095F 0x00000000" = {
          pos = "3710 2880";
          resolution = "2256x1504";
          scale = "1";
        };
        # Framework (again?)
        "BOE 0x095F Unknown" = {
          pos = "3816 3317";
          resolution = "2256x1504";
          scale = "1.5";
        };
        "Unknown HP Z27 CN49020L9R" = {
          pos = "6010 1440";
          resolution = "1920x1200";
          scale = "1";
          transform = "270";
        };
        "HP Inc. HP Z27 CN49020L9R" = {
          pos = "8654 2880";
          resolution = "3840x2160";
          scale = "2";
          transform = "270";
        };
        "Dell Inc. Dell U4924DW 3KWV0S3" = {
          pos = "5320 2880";
          resolution = "5120x1440";
          scale = "1";
        };
      };

      workspaceOutputAssign = let
        primary-output = "Dell Inc. Dell U4924DW 3KWV0S3";
        secondary-output = "Unknown 0x5A2D 0x00000000";
      in [
        {
          workspace = "1";
          output = "${primary-output} ${secondary-output}";
        }
        {
          workspace = "2";
          output = "${primary-output} ${secondary-output}";
        }
        {
          workspace = "3";
          output = "${primary-output} ${secondary-output}";
        }
        {
          workspace = "4";
          output = "${primary-output} ${secondary-output}";
        }
        {
          workspace = "5";
          output = "${primary-output} ${secondary-output}";
        }
        {
          workspace = "6";
          output = "${primary-output} ${secondary-output}";
        }
        {
          workspace = "7";
          output = "${secondary-output} ${primary-output}";
        }
        {
          workspace = "8";
          output = "${secondary-output} ${primary-output}";
        }
        {
          workspace = "9";
          output = "${secondary-output} ${primary-output}";
        }
        {
          workspace = "0";
          output = "${secondary-output} ${primary-output}";
        }
      ];

      keybindings = let
        modifier = config.wayland.windowManager.sway.config.modifier;
      in
        lib.mkOptionDefault {
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
          "${modifier}+c" = "exec rofi -modes calc -show calc";
          "${modifier}+u" = "exec firefox";
          "${modifier}+t" = "exec kitty -- ${pkgs.ranger}/bin/ranger ~/Downloads";
          "${modifier}+i" = "exec ${pkgs.blueberry}/bin/blueberry";
          "${modifier}+o" = "exec ${pkgs.rofi-bluetooth}/bin/rofi-bluetooth";
          "${modifier}+p" = "exec ${pkgs.swaylock}/bin/swaylock -f -c 000088";
          "${modifier}+m" = "exec ${pkgs.warpd}/bin/warpd --hint";

          # Controls
          "XF86AudioMute" = "exec ${pkgs.pamixer}/bin/pamixer -t";
          "XF86AudioMicMute" = "exec ${pkgs.pamixer}/bin/pamixer --default-source -t";
          "XF86AudioLowerVolume" = "exec ${pkgs.pamixer}/bin/pamixer -d 10";
          "XF86AudioRaiseVolume" = "exec ${pkgs.pamixer}/bin/pamixer -i 10";
          "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
          "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";
          "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
          "Print" = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.swappy}/bin/swappy -f -";
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
          xkb_layout = "us";
        };
        "1133:45088:MX_Vertical_Mouse" = {
          accel_profile = "flat";
          pointer_accel = "-0.2";
        };
        "2362:628:PIXA3854:00_093A:0274_Touchpad" = {
          tap = "enabled";
          tap_button_map = "lrm";
          dwt = "enabled";
        };
      };
    };
  };
}
