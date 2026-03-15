# Hyprland window manager configuration
{ inputs, ... }:
{
  # Overlay: Pin hyprland version from flake input
  flake.overlays.hyprland = final: prev: {
    hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland;
  };

  # NixOS hyprland configuration
  # Uses mkDefault to avoid conflicts with legacy config during transition
  flake.modules.nixos.hyprland =
    { pkgs, lib, ... }:
    {
      programs.hyprland = {
        enable = lib.mkDefault true;
        package = lib.mkDefault inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        withUWSM = lib.mkDefault true;
      };

      services.hypridle.enable = lib.mkDefault true;
      programs.regreet.enable = lib.mkDefault true;
      services.greetd.enable = lib.mkDefault true;

      # Disable fingerprint auth for greetd — fprintd blocks the PAM
      # conversation, preventing password fallback in regreet.
      # Fingerprint still works for sudo, hyprlock, etc.
      security.pam.services.greetd.fprintAuth = false;

      # Create PAM service for hyprlock (prevents "falling back to /etc/pam.d/su").
      # Disable PAM-level fingerprint here because hyprlock uses fprintd's D-Bus
      # API directly (auth.fingerprint.enabled) — having both causes double prompts.
      # https://github.com/hyprwm/hyprlock/issues/953
      security.pam.services.hyprlock.fprintAuth = false;

      # Stop fprintd before suspend so it starts fresh on resume via D-Bus
      # activation. Prevents stale device state that delays fingerprint verification.
      # https://github.com/hyprwm/hyprlock/issues/577
      # https://github.com/NixOS/nixpkgs/issues/432276
      powerManagement.powerDownCommands = ''
        ${pkgs.systemd}/bin/systemctl stop fprintd.service 2>/dev/null || true
      '';

      services.logind.settings.Login = {
        HandleLidSwitch = lib.mkDefault "suspend";
        HandleLidSwitchDocked = lib.mkDefault "ignore";
        HandleLidSwitchExternalPower = lib.mkDefault "suspend";
      };
    };

  # Home-manager hyprland configuration
  flake.modules.homeManager.hyprland =
    { config, pkgs, lib, ... }:
    {
      services.hyprpolkitagent.enable = true;

      wayland.windowManager.hyprland = {
        enable = true;
        systemd.enable = true; # Required for hyprland-session.target (ashell depends on it)
        # xwayland.enable = true;
        plugins = [
          inputs.hy3.packages.${pkgs.stdenv.hostPlatform.system}.hy3
        ];

        settings =
          let
            layoutAware =
              dispatcher: direction:
              ''exec, sh -c 'cur=$(hyprctl -j getoption general:layout | ${pkgs.jq}/bin/jq -r .str); if [ "$cur" = "hy3" ]; then hyprctl dispatch hy3:${dispatcher} ${direction}; else hyprctl dispatch ${dispatcher} ${direction}; fi' '';

            brightnessAdjust = pkgs.writeShellScript "brightness-adjust" ''
              CHANGE=$1
              # Determine monitor by cursor position, not window focus
              CURSOR_X=$(hyprctl cursorpos -j | ${pkgs.jq}/bin/jq '.x')
              CURSOR_Y=$(hyprctl cursorpos -j | ${pkgs.jq}/bin/jq '.y')
              MONITOR=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r \
                --argjson cx "$CURSOR_X" --argjson cy "$CURSOR_Y" \
                '.[] | select(.x <= $cx and $cx < (.x + .width / .scale) and .y <= $cy and $cy < (.y + .height / .scale)) | .name')

              case $MONITOR in
                eDP-1)
                  if [ $CHANGE -lt 0 ]; then
                    ${pkgs.brightnessctl}/bin/brightnessctl set "''${CHANGE#-}%-"
                  else
                    ${pkgs.brightnessctl}/bin/brightnessctl set "''${CHANGE}%+"
                  fi
                  ;;
                DP-*)
                  # Auto-detect I2C bus for the DP connector (cached in /tmp)
                  CACHE="/tmp/ddc-bus-$MONITOR"
                  BUS=$(cat "$CACHE" 2>/dev/null)
                  if [ -z "$BUS" ]; then
                    BUS=$(${pkgs.ddcutil}/bin/ddcutil detect 2>/dev/null | ${pkgs.gawk}/bin/awk '/I2C bus:/{bus=$NF} /DRM_connector:.*card[0-9]+-'"$MONITOR"'/{gsub(/.*i2c-/,"",bus); print bus; exit}')
                    [ -z "$BUS" ] && exit 1
                    echo "$BUS" > "$CACHE"
                  fi
                  CURRENT=$(${pkgs.ddcutil}/bin/ddcutil --bus $BUS getvcp 10 --terse 2>/dev/null | cut -d' ' -f4)
                  [ -z "$CURRENT" ] && exit 1
                  NEW=$((CURRENT + CHANGE))
                  [ $NEW -lt 0 ] && NEW=0
                  [ $NEW -gt 100 ] && NEW=100
                  ${pkgs.ddcutil}/bin/ddcutil --bus $BUS --noverify setvcp 10 $NEW
                  ;;
              esac
            '';

            monitorAttached = pkgs.writeShellScript "monitor-attached" ''
              JQ="${pkgs.jq}/bin/jq"
              MONITOR="$1"

              # Invalidate DDC bus cache on monitor change
              rm -f /tmp/ddc-bus-*

              # Get external monitor info
              MONITOR_INFO=$(hyprctl monitors -j | $JQ -r ".[] | select(.name == \"$MONITOR\")")
              MONITOR_DESC=$(echo "$MONITOR_INFO" | $JQ -r ".description")
              MONITOR_WIDTH=$(echo "$MONITOR_INFO" | $JQ -r ".width")

              # Get laptop panel info dynamically
              LAPTOP=$(hyprctl monitors -j | $JQ '.[] | select(.name == "eDP-1")')
              LAPTOP_W=$(echo "$LAPTOP" | $JQ -r '.width')
              LAPTOP_H=$(echo "$LAPTOP" | $JQ -r '.height')
              LAPTOP_RR=$(echo "$LAPTOP" | $JQ -r '.refreshRate' | cut -d. -f1)
              LAPTOP_SCALE=$(echo "$LAPTOP" | $JQ -r '.scale')
              LAPTOP_MODE="''${LAPTOP_W}x''${LAPTOP_H}@''${LAPTOP_RR}"
              LAPTOP_LOGICAL=$(echo "$LAPTOP_W / $LAPTOP_SCALE" | ${pkgs.bc}/bin/bc -l | cut -d. -f1)

              # Move workspaces 1-6 to the newly attached monitor
              for ws in 1 2 3 4 5 6; do
                hyprctl dispatch moveworkspacetomonitor "$ws" "$MONITOR"
              done
              # Switch to workspace 1 on the new monitor
              hyprctl dispatch workspace 1

              # Detect ultrawide: Dell U4924DW or any 5120-width monitor
              if echo "$MONITOR_DESC" | grep -qi "U4924DW" || [ "$MONITOR_WIDTH" = "5120" ]; then
                ${pkgs.libnotify}/bin/notify-send "Monitor: Ultrawide" "Layout: master, ultrawide on top"
                # Home setup: Ultrawide on TOP of laptop, master layout
                hyprctl keyword general:layout master
                # Center laptop below ultrawide
                LAPTOP_X=$(( (5120 - LAPTOP_LOGICAL) / 2 ))
                hyprctl keyword monitor "$MONITOR,5120x1440@60,0x0,1"
                hyprctl keyword monitor "eDP-1,''${LAPTOP_MODE},''${LAPTOP_X}x1440,''${LAPTOP_SCALE}"
              else
                ${pkgs.libnotify}/bin/notify-send "Monitor: Portable" "Layout: hy3, external on right"
                # Portable monitor setup: external on RIGHT of laptop
                hyprctl keyword general:layout hy3
                hyprctl keyword monitor "eDP-1,''${LAPTOP_MODE},0x0,''${LAPTOP_SCALE}"
                hyprctl keyword monitor "$MONITOR,preferred,''${LAPTOP_LOGICAL}x0,1"
              fi

              # Reload hyprpaper to apply wallpaper to new monitor
              killall hyprpaper; sleep 0.5; ${pkgs.hyprpaper}/bin/hyprpaper &
            '';

            monitorDetached = pkgs.writeShellScript "monitor-detached" ''
              JQ="${pkgs.jq}/bin/jq"
              # Invalidate DDC bus cache on monitor change
              rm -f /tmp/ddc-bus-*
              # Switch back to hy3 layout for laptop-only mode
              hyprctl keyword general:layout hy3
              # Reset laptop monitor position dynamically
              LAPTOP=$(hyprctl monitors -j | $JQ '.[] | select(.name == "eDP-1")')
              W=$(echo "$LAPTOP" | $JQ -r '.width')
              H=$(echo "$LAPTOP" | $JQ -r '.height')
              RR=$(echo "$LAPTOP" | $JQ -r '.refreshRate' | cut -d. -f1)
              SCALE=$(echo "$LAPTOP" | $JQ -r '.scale')
              hyprctl keyword monitor "eDP-1,''${W}x''${H}@''${RR},0x0,''${SCALE}"
              # Reload hyprpaper to apply wallpaper
              killall hyprpaper; sleep 0.5; ${pkgs.hyprpaper}/bin/hyprpaper &
            '';
            scaleToggle = pkgs.writeShellScript "scale-toggle" ''
              JQ="${pkgs.jq}/bin/jq"
              SCALE_FILE="/tmp/hypr-default-scale"
              MONITORS=$(hyprctl monitors -j)
              LAPTOP=$(echo "$MONITORS" | $JQ '.[] | select(.name == "eDP-1")')
              CURRENT=$(echo "$LAPTOP" | $JQ -r '.scale')
              W=$(echo "$LAPTOP" | $JQ -r '.width')
              H=$(echo "$LAPTOP" | $JQ -r '.height')
              RR=$(echo "$LAPTOP" | $JQ -r '.refreshRate' | cut -d. -f1)
              EXT=$(echo "$MONITORS" | $JQ -r '.[] | select(.name != "eDP-1") | .name' | head -1)

              # Save default scale on first run
              [ ! -f "$SCALE_FILE" ] && echo "$CURRENT" > "$SCALE_FILE"
              DEFAULT_SCALE=$(cat "$SCALE_FILE")

              if [ "$(echo "$CURRENT > 1.1" | ${pkgs.bc}/bin/bc -l)" = "1" ]; then
                NEW_SCALE=1
                LABEL="scale 1.0 (native)"
              else
                NEW_SCALE="$DEFAULT_SCALE"
                LABEL="scale $DEFAULT_SCALE"
              fi

              # Build a batch of monitor commands to apply atomically
              BATCH="keyword monitor eDP-1,''${W}x''${H}@''${RR},0x0,$NEW_SCALE;"
              if [ -n "$EXT" ]; then
                BATCH="$BATCH keyword monitor $EXT,preferred,auto,$NEW_SCALE;"
              fi
              hyprctl --batch "$BATCH"

              ${pkgs.libnotify}/bin/notify-send "eDP-1: $LABEL"
            '';

            screenRecord = pkgs.writeShellScript "screen-record-toggle" ''
              if ${pkgs.procps}/bin/pkill -INT wl-screenrec 2>/dev/null; then
                ${pkgs.libnotify}/bin/notify-send "Recording saved"
              else
                GEOM=$(${pkgs.slurp}/bin/slurp) || exit 0
                ${pkgs.wl-screenrec}/bin/wl-screenrec -g "$GEOM" --filename="$HOME/Screenshots/$(date +%Y-%m-%d-%H%M%S).mp4" &
                ${pkgs.libnotify}/bin/notify-send "Recording started"
              fi
            '';
            whichKeyConfig = (pkgs.formats.yaml { }).generate "wlr-which-key-config.yaml" {
              font = "JetBrainsMono Nerd Font 14";
              background = "#1e1e2eee";
              color = "#cdd6f4";
              border = "#89b4fa";
              separator = " → ";
              border_width = 2;
              corner_r = 10;
              padding = 15;
              anchor = "center";
              menu = [
                { key = "f"; desc = "Firefox"; cmd = "firefox"; }
                { key = "s"; desc = "Sound"; cmd = "${pkgs.pavucontrol}/bin/pavucontrol"; }
                { key = "o"; desc = "Toggle Audio Output"; cmd = "${toggleAudioOutput}"; }
                { key = "b"; desc = "Bluetooth"; cmd = "${pkgs.blueberry}/bin/blueberry"; }
                { key = "t"; desc = "Files"; cmd = "kitty -- ${pkgs.ranger}/bin/ranger ~/Downloads"; }
                { key = "a"; desc = "Claude"; cmd = "firefox https://claude.ai"; }
              ];
            };
            toggleAudioOutput = pkgs.writeShellScript "toggle-audio-output" ''
              pactl="${pkgs.pulseaudio}/bin/pactl"
              notify="${pkgs.libnotify}/bin/notify-send"
              grep="${pkgs.gnugrep}/bin/grep"
              awk="${pkgs.gawk}/bin/awk"

              # Get all sink IDs and current default
              ids=($($pactl list sinks short | $awk '{print $1}'))
              default_name=$($pactl get-default-sink)
              current_id=$($pactl list sinks short | $grep "$default_name" | $awk '{print $1}')

              # Cycle to next sink
              next_id="''${ids[0]}"
              for i in "''${!ids[@]}"; do
                if [ "''${ids[$i]}" = "$current_id" ]; then
                  next_idx=$(( (i + 1) % ''${#ids[@]} ))
                  next_id="''${ids[$next_idx]}"
                  break
                fi
              done

              # Set new default and move all playing streams
              $pactl set-default-sink "$next_id"
              for input in $($pactl list sink-inputs short | $awk '{print $1}'); do
                $pactl move-sink-input "$input" "$next_id"
              done

              new_name=$($pactl list sinks | $grep -A1 "Sink #$next_id" | $grep Description | sed 's/.*: //')
              $notify "Audio Output" "$new_name"
            '';
            micMuteAll = pkgs.writeShellScript "mic-mute-all" ''
              wpctl="${pkgs.wireplumber}/bin/wpctl"
              notify="${pkgs.libnotify}/bin/notify-send"
              grep="${pkgs.gnugrep}/bin/grep"

              # Extract audio sources section from wpctl status
              sources=$($wpctl status | sed -n '/Audio/,/Video/p' | sed -n '/Sources:/,/Filters:/p')

              # Get all audio source node IDs (match "67." pattern, not "1.00" from volume)
              ids=$(echo "$sources" | $grep -oP '\d+(?=\. )')

              # Determine current state from the default source (marked with *)
              default_id=$(echo "$sources" | $grep '\*' | $grep -oP '\d+(?=\. )' | head -1)
              current=$($wpctl get-volume "$default_id" 2>/dev/null)

              if echo "$current" | $grep -q MUTED; then
                action=0  # unmute
                led=0     # LED off = mic active
                msg="Microphones ON"
                icon="microphone-sensitivity-high-symbolic"
              else
                action=1  # mute
                led=1     # LED on = mic muted
                msg="All Microphones MUTED"
                icon="microphone-sensitivity-muted-symbolic"
              fi

              for id in $ids; do
                $wpctl set-mute "$id" "$action"
              done

              # Sync the physical mic mute LED directly via sysfs
              echo "$led" > /sys/class/leds/platform::micmute/brightness 2>/dev/null

              $notify -i "$icon" -t 2000 -h string:x-canonical-private-synchronous:mic-mute "$msg"
            '';
            myMenu = pkgs.writeShellScriptBin "my-menu" ''
              exec ${lib.getExe pkgs.wlr-which-key} ${whichKeyConfig}
            '';
            # Daemon that warps the cursor to XWayland popups (Synology Drive,
            # Zoom menus) when they open.  With follow_mouse=1, these popups
            # spawn away from the cursor, immediately lose focus, and close.
            # Warping the cursor keeps follow_mouse happy.
            # Warp cursor to XWayland popups (Synology Drive, Zoom menus)
            # when they open.  With follow_mouse=1, these popups spawn away
            # from the cursor, immediately lose focus, and close.
            popupFocusDaemon = pkgs.writeShellScript "popup-focus-daemon" ''
              JQ="${pkgs.jq}/bin/jq"
              SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
              ${pkgs.socat}/bin/socat -u UNIX-CONNECT:"$SOCKET" - | while IFS= read -r line; do
                case "$line" in
                  openwindow*cloud-drive-ui*|openwindow*menu\ window*)
                    sleep 0.05
                    ADDR="''${line#*>>}"
                    ADDR="0x''${ADDR%%,*}"
                    # Get window position and size, warp cursor to its center
                    WIN=$(hyprctl clients -j | $JQ ".[] | select(.address == \"$ADDR\")")
                    X=$(echo "$WIN" | $JQ '.at[0] + (.size[0] / 2) | floor')
                    Y=$(echo "$WIN" | $JQ '.at[1] + (.size[1] / 2) | floor')
                    [ "$X" != "null" ] && hyprctl dispatch movecursor "$X" "$Y"
                    ;;
                esac
              done
            '';
          in
          {
            # Default monitor config for undocked state (applies on Hyprland start/restart)
            monitor = lib.mkDefault "eDP-1,2256x1504@60,0x0,1.5666667";

            # Render XWayland apps at native resolution instead of blurry upscaling
            xwayland.force_zero_scaling = true;

            env = [
              "GDK_SCALE,2"
              "XCURSOR_SIZE,32"
            ];

            general = {
              layout = "hy3";
              border_size = 4;
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

            # Prevent XWayland ghost windows (empty class+title) from stealing
            # focus, which causes popups in apps like Zoom and Synology Drive
            # to vanish when you try to mouse over them.
            windowrulev2 = [
              "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
            ];

            "$mod" = "SUPER";

            exec-once = [
              "${pkgs.hyprpaper}/bin/hyprpaper"
              "${pkgs.hyprland-monitor-attached}/bin/hyprland-monitor-attached ${monitorAttached} ${monitorDetached}"
              # Run initial setup based on current monitor state (hyprland-monitor-attached only handles events)
              "sh -c 'sleep 3; ext=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r \".[] | select(.name != \\\"eDP-1\\\") | .name\" | head -1); if [ -n \"$ext\" ]; then ${monitorAttached} \"$ext\"; else ${monitorDetached}; fi'"
              "${pkgs.synology-drive-client}/bin/synology-drive"
              "${popupFocusDaemon}"
            ];

            bind = [
              # Window management
              "$mod, Q, exec, sh -c 'cur=$(hyprctl -j getoption general:layout | ${pkgs.jq}/bin/jq -r .str); [ \"$cur\" = \"hy3\" ] && hyprctl dispatch hy3:killactive || hyprctl dispatch killactive'"
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
              "$mod CTRL SHIFT, L, movecurrentworkspacetomonitor, r"
              "$mod CTRL SHIFT, H, movecurrentworkspacetomonitor, l"
              "$mod CTRL SHIFT, J, movecurrentworkspacetomonitor, d"
              "$mod CTRL SHIFT, K, movecurrentworkspacetomonitor, u"

              # Launch programs
              "$mod, Return, exec, ghostty"
              "$mod SHIFT, Return, hy3:makegroup, v"
              "$mod, W, hy3:makegroup, tab"
              "$mod, E, hy3:changegroup, tab"
              "$mod SHIFT, W, hy3:changegroup, untab"
              "$mod, R, exec, rofi -modes run -show run"
              "$mod, C, exec, rofi -modes calc -show calc"
              "$mod, B, exec, firefox"
              "$mod, A, exec, firefox https://claude.ai"
              "$mod, T, exec, kitty -- ${pkgs.ranger}/bin/ranger ~/Downloads"
              "$mod, I, exec, ${pkgs.blueberry}/bin/blueberry"
              "$mod, P, exec, ${pkgs.hyprlock}/bin/hyprlock"
              "$mod, M, exec, ${pkgs.wl-kbptr}/bin/wl-kbptr -o modes=floating,bisect,click -o mode_floating.source=detect"

              # Window and group management
              "$mod, F, togglefloating"
              "$mod, H, ${layoutAware "movefocus" "l"}"
              "$mod, L, ${layoutAware "movefocus" "r"}"
              "$mod, K, ${layoutAware "movefocus" "u"}"
              "$mod, J, ${layoutAware "movefocus" "d"}"
              "$mod, Y, exec, sh -c 'cur=$(hyprctl -j getoption general:layout | ${pkgs.jq}/bin/jq -r .str); [ \"$cur\" = \"hy3\" ] && hyprctl keyword general:layout master || hyprctl keyword general:layout hy3'"
              "$mod, D, exec, ${myMenu}/bin/my-menu"
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
              ", XF86AudioMicMute, exec, ${micMuteAll}"
              ", XF86AudioLowerVolume, exec, ${pkgs.pamixer}/bin/pamixer -d 10"
              ", XF86AudioRaiseVolume, exec, ${pkgs.pamixer}/bin/pamixer -i 10"
              ", XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
              ", XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next"
              ", XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous"
              ", Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.swappy}/bin/swappy -f -"
              "SHIFT, Print, exec, ${screenRecord}"
              ", 164, exec, ${pkgs.playerctl}/bin/playerctl play-pause"
              ", 232, exec, ${brightnessAdjust} -15"
              ", 233, exec, ${brightnessAdjust} +15"

              # Display
              "$mod, S, exec, ${scaleToggle}"

              # Notifications
              "$mod, N, exec, ${pkgs.mako}/bin/makoctl dismiss"
            ];

            bindm = [
              "$mod, mouse:272, movewindow"
              "$mod, mouse:273, resizewindow"
            ];
          };
      };

      # UWSM environment configuration
      # xdg.configFile."uwsm/env".source =
      #   "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
    };

  # Hyprlock and hypridle session management
  flake.modules.homeManager.hyprSession =
    { lib, config, pkgs, ... }:
    let
      fprintDpmsWake = pkgs.writeShellScript "fprint-dpms-wake" ''
        # Wake display when fingerprint reader is touched.
        # fprintd emits VerifyStatus on scan (match, no-match, retry, etc.)
        # Workaround: the touch that wakes DPMS is consumed as a failed scan
        # (verify-no-match), requiring a second touch to unlock.
        # https://github.com/hyprwm/hyprlock/issues/538
        ${pkgs.dbus}/bin/dbus-monitor --system \
          "type='signal',interface='net.reactivated.Fprint.Device',member='VerifyStatus'" |
          while read -r _; do
            hyprctl dispatch dpms on 2>/dev/null
          done
      '';
    in
    {
      programs.hyprlock = {
        enable = true;
        settings = {
          general = {
            hide_cursor = true;
            ignore_empty_input = true;
          };
          auth = {
            fingerprint = {
              enabled = true;
              ready_message = "Scan fingerprint to unlock";
              present_message = "Scanning...";
            };
          };
          background = lib.mkForce [
            {
              path = "${config.stylix.image}";
              blur_passes = 3;
              blur_size = 8;
            }
          ];
          input-field = lib.mkForce [
            {
              position = "0, -80";
            }
          ];
        };
      };

      systemd.user.services.fprint-dpms-wake = {
        Unit = {
          Description = "Wake display on fingerprint reader activity";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${fprintDpmsWake}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "pidof hyprlock || hyprlock";
            unlock_cmd = "hyprctl dispatch dpms on";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch dpms on && sleep 1 && hyprctl reload";
            # Wait for hyprlock to fully lock the session before allowing suspend.
            # Prevents race where suspend interleaves with fprint verification.
            # https://github.com/hyprwm/hyprlock/issues/577
            inhibit_sleep = 3;
          };
          listener = [
            {
              timeout = 120;
              # Use loginctl lock-session instead of launching hyprlock directly.
              # This triggers hypridle's lock_cmd via the systemd lock protocol,
              # preventing duplicate instances more reliably.
              on-timeout = "loginctl lock-session";
            }
            {
              timeout = 1800;
              on-timeout = "1password --lock";
            }
            {
              timeout = 180;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
            {
              timeout = 600;
              on-timeout = "systemctl suspend";
            }
          ];
        };
      };
    };
}
