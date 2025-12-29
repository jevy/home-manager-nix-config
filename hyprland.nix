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
    # xwayland.enable = true;
    plugins = [ hy3.packages.x86_64-linux.hy3 ];

    settings =
      let
        layoutAware =
          dispatcher: direction:
          ''exec, sh -c 'cur=$(hyprctl -j getoption general:layout | ${pkgs.jq}/bin/jq -r .str); if [ "$cur" = "hy3" ]; then hyprctl dispatch hy3:${dispatcher} ${direction}; else hyprctl dispatch ${dispatcher} ${direction}; fi' '';
      in
      {
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

        master = {
          orientation = "center";
          mfact = 0.45; # Master window takes 45% of screen width
          slave_count_for_center_master = 0; # Always center master (even with no slaves)
          new_status = "slave"; # New windows go to slave stack
          smart_resizing = true;
        };
        monitor = [
          "eDP-1, 2256x1504, 0x0, 1.57"
          "DP-1, 2560x1600, 1440x0, 1.6"
          # "desc:BOE 0x095F, preferred, auto, 1.5666"
          # "desc:Dell Inc. Dell U4924DW 3KWV0S3,5120x1440@60,5320x2880,1"
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

        dwindle = {
          preserve_split = true;
          single_window_aspect_ratio = "16 9";
          single_window_aspect_ratio_tolerance = 0.1;
          split_width_multiplier = 1.15;
        };

        "$mod" = "SUPER";

        exec-once = "${pkgs.hyprpaper}/bin/hyprpaper";

        bind = [
          # Window management
          "$mod, Q, hy3:killactive"
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
          "$mod, P, exec, ${pkgs.hyprlock}/bin/hyprlock"
          "$mod, M, exec, ${pkgs.warpd}/bin/warpd --hint"

          # Window and group management
          "$mod, F, togglefloating"
          "$mod, H, ${layoutAware "movefocus" "l"}"
          "$mod, L, ${layoutAware "movefocus" "r"}"
          "$mod, K, ${layoutAware "movefocus" "u"}"
          "$mod, J, ${layoutAware "movefocus" "d"}"
          "$mod, Y, exec, sh -c 'cur=$(hyprctl -j getoption general:layout | ${pkgs.jq}/bin/jq -r .str); [ \"$cur\" = \"hy3\" ] && hyprctl keyword general:layout master || hyprctl keyword general:layout hy3'"
          "$mod, D, exec, hyprctl keyword general:layout master"
          "$mod SHIFT, F, fullscreen"
          "$mod SHIFT, L, ${layoutAware "movewindow" "r"}"
          "$mod SHIFT, H, ${layoutAware "movewindow" "l"}"
          "$mod SHIFT, K, ${layoutAware "movewindow" "u"}"
          "$mod SHIFT, J, ${layoutAware "movewindow" "d"}"

          # Tab navigation (similar to Sway's group navigation)
          "$mod, O, hy3:focustab, r"
          "$mod, U, hy3:focustab, l"
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

          # Notifications
          "$mod, N, exec, ${pkgs.mako}/bin/makoctl dismiss"
        ];
      };
  };

  # UWSM environment configuration
  # xdg.configFile."uwsm/env".source =
  #   "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
