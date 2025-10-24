{
  config,
  pkgs,
  lib,
  hy3,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    plugins = [ hy3.packages.x86_64-linux.hy3 ];

    settings = {
      general = {
        layout = "hy3";
      };

      plugin = {
        hy3 = {
          no_gaps_when_only = 1;
          node_collapse_policy = 2;
          
          tabs = {
            height = 22;
            padding = 6;
            from_top = false;
            render_text = true;
            text_center = true;
            text_height = 8;
          };
        };
      };
      monitor = [
        "desc:BOE 0x095F, preferred, auto, 1.5666"
        "desc:Dell Inc. Dell U4924DW 3KWV0S3,5120x1440@60,5320x2880,1"
      ];

      # workspace = [
      #   "1, monitor:Dell Inc. Dell U4924DW 3KWV0S3"
      #   "2, monitor:Dell Inc. Dell U4924DW 3KWV0S3"
      #   "3, monitor:Dell Inc. Dell U4924DW 3KWV0S3"
      #   "4, monitor:Dell Inc. Dell U4924DW 3KWV0S3"
      #   "5, monitor:Dell Inc. Dell U4924DW 3KWV0S3"
      #   "6, monitor:Dell Inc. Dell U4924DW 3KWV0S3"
      #   "7, monitor:Unknown 0x5A2D 0x00000000"
      #   "8, monitor:Unknown 0x5A2D 0x00000000"
      #   "9, monitor:Unknown 0x5A2D 0x00000000"
      #   "10, monitor:Unknown 0x5A2D 0x00000000"
      # ];

      input = {
        "kb_layout" = "us";
        "kb_options" = "ctrl:nocaps";
        "follow_mouse" = 1;
        "touchpad" = {
          "tap-to-click" = true;
          "tap_button_map" = "lrm";
          "disable_while_typing" = true;
        };
      };

      animations = {
        enabled = true;
      };

      "$mod" = "SUPER";

      bind = [
        # Window management
        "$mod, Q, hy3:killactive"
        "$mod SHIFT, Q, exit"
        "$mod SHIFT, R, exec, hyprctl reload"

        # Workspace navigation
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move windows to workspaces
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Workspace movement
        "$mod CTRL SHIFT, L, moveworkspacetomonitor, r"
        "$mod CTRL SHIFT, H, moveworkspacetomonitor, l"
        "$mod CTRL SHIFT, J, moveworkspacetomonitor, d"
        "$mod CTRL SHIFT, K, moveworkspacetomonitor, u"

        # Launch programs
        "$mod, Return, exec, ghostty"
        "$mod SHIFT, Return, hy3:makegroup, v"
        "$mod, W, hy3:makegroup, tab"
        "$mod, E, hy3:changegroup, tab"
        "$mod SHIFT, W, hy3:changegroup, untab"
        "$mod, R, exec, rofi -modes run -show run"
        "$mod, C, exec, rofi -modes calc -show calc"
        "$mod, B, exec, firefox"
        "$mod, T, exec, kitty -- ${pkgs.ranger}/bin/ranger ~/Downloads"
        "$mod, I, exec, ${pkgs.blueberry}/bin/blueberry"
        "$mod, P, exec, ${pkgs.swaylock}/bin/swaylock -f -c 000088"
        "$mod, M, exec, ${pkgs.warpd}/bin/warpd --hint"
        
        # Window and group management
        "$mod, F, togglefloating"
        "$mod, H, hy3:movefocus, l"
        "$mod, L, hy3:movefocus, r"
        "$mod, K, hy3:movefocus, u"
        "$mod, J, hy3:movefocus, d"
        "$mod SHIFT, F, fullscreen"
        "$mod SHIFT, L, hy3:movewindow, r"
        "$mod SHIFT, H, hy3:movewindow, l"
        "$mod SHIFT, K, hy3:movewindow, u"
        "$mod SHIFT, J, hy3:movewindow, d"
        
        # Tab navigation (similar to Sway's group navigation)
        "$mod, O, hy3:focustab, r, wrap"
        "$mod, U, hy3:focustab, l, wrap"
        "$mod SHIFT, O, hy3:movewindow, r, once"
        "$mod SHIFT, U, hy3:movewindow, l, once"

        # Media controls
        ", XF86AudioMute, exec, ${pkgs.pamixer}/bin/pamixer -t"
        ", XF86AudioMicMute, exec, ${pkgs.pamixer}/bin/pamixer --default-source -t"
        ", XF86AudioLowerVolume, exec, ${pkgs.pamixer}/bin/pamixer -d 10"
        ", XF86AudioRaiseVolume, exec, ${pkgs.pamixer}/bin/pamixer -i 10"
        ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
        ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"
        ", Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.swappy}/bin/swappy -f -"
        ", 164, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
        ", 232, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%-"
        ", 233, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 5%+"
      ];
    };
  };

  # UWSM environment configuration
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
