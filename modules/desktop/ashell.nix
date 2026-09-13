# Ashell status bar for Hyprland
{ ... }:
{
  flake.modules.homeManager.ashell =
    { config, pkgs, ... }:
    let
      weather-listen = pkgs.writeShellScript "ashell-weather.sh" ''
        export KEY_FILE="${config.sops.secrets.openweathermap_api_key.path}"
        while true; do
            weather_output=$(/home/jevin/.config/nixpkgs/waybar/polybar/openweathermap-forecast.sh)
            if [ -n "$weather_output" ]; then
                echo "{\"text\": \"$weather_output\", \"alt\": \"weather\"}"
                sleep 600
            else
                echo "{\"text\": \"Weather unavailable\", \"alt\": \"error\"}"
                sleep 15
            fi
        done
      '';

      # ashell owns org.kde.StatusNotifierWatcher, the tray registry that every
      # Qt/GTK app probes during GUI init. Seen on 0.9.0: that handler stops
      # answering while ashell keeps the bus name, so the probe runs into
      # D-Bus's 25s default timeout and *every* tray-aware app (VLC from yazi,
      # etc.) takes 25s to show a window. The bar itself looks perfectly fine,
      # which makes it near-impossible to attribute. Restarting ashell clears
      # it. This watchdog does that automatically; drop it once upstream fixes
      # the wedge (nothing in the 0.10.0 changelog names it).
      tray-watchdog = pkgs.writeShellScript "ashell-tray-watchdog.sh" ''
        set -u

        SYSTEMCTL=${pkgs.systemd}/bin/systemctl

        $SYSTEMCTL --user is-active --quiet ashell || exit 0

        # Don't fight a bar that is still coming up: the ExecStartPre nm-online
        # above can hold startup for 30s, and the tray name appears after that.
        # Age comes from `ps -o etimes` (wall seconds since the process
        # started). Do NOT compute it from systemd's *TimestampMonotonic minus
        # /proc/uptime: systemd's monotonic clock excludes suspend time and
        # /proc/uptime includes it, so on this laptop those two differ by days.
        pid=$($SYSTEMCTL --user show ashell -p MainPID --value)
        [ -n "$pid" ] && [ "$pid" != 0 ] || exit 0
        age=$(${pkgs.procps}/bin/ps -o etimes= -p "$pid" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' ')
        [ -n "$age" ] || exit 0
        [ "$age" -lt 90 ] && exit 0

        # A healthy watcher answers in ~1ms, so 3s is generous. Two failures 5s
        # apart, to ride out a momentary stall during tray re-registration.
        probe() {
          ${pkgs.coreutils}/bin/timeout 3 ${pkgs.systemd}/bin/busctl --user \
            get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
            org.kde.StatusNotifierWatcher IsStatusNotifierHostRegistered \
            >/dev/null 2>&1
        }

        probe && exit 0
        ${pkgs.coreutils}/bin/sleep 5
        probe && exit 0

        echo "ashell tray watcher unresponsive (2 probes, ashell up $age s); restarting" >&2
        $SYSTEMCTL --user restart ashell
      '';

      timetagger-listen = pkgs.writeShellScript "ashell-timetagger.sh" ''
        while true; do
          running_line=$(${pkgs.timetagger_cli}/bin/timetagger status 2>/dev/null | grep '^Running:')

          if echo "$running_line" | grep -q 'N/A'; then
            echo '{"text": "", "alt": "idle"}'
          elif [ -n "$running_line" ]; then
            # Format: "Running: 0:48 - task description #tags"
            duration=$(echo "$running_line" | sed 's/^Running: *\([^ ]*\) - .*/\1/')
            description=$(echo "$running_line" | sed 's/^Running: *[^ ]* - //')
            echo "{\"text\": \"$description ($duration)\", \"alt\": \"running\"}"
          else
            echo '{"text": "", "alt": "error"}'
          fi

          sleep 30
        done
      '';
    in
    {
      home.packages = [ pkgs.libnotify ];
      programs.ashell = {
        enable = true;
        systemd.enable = true;
        systemd.target = "hyprland-session.target";
        settings = {
          modules = {
            left = [ "Workspaces" ];
            center = [ "CalendarMeetings" ];
            right = [
              "TimeTagger"
              "CustomWeather"
              "MediaPlayer"
              "Tray"
              [
                "Volume"
                "Privacy"
                "Settings"
                "Tempo"
              ]
            ];
          };
          # ashell 0.9.0 renamed the Clock module to Tempo: the module name is
          # "Tempo", the [clock] section is now [tempo], and `format` is now
          # `clock_format`. Weather stays in the separate CustomWeather module,
          # so Tempo runs clock-only (no weather_location).
          tempo = {
            clock_format = "%a %d %b %l:%M %p";
          };
          CustomModule = [
            {
              name = "CustomWeather";
              icon = "";
              command = "wget -O - http://wttr.in/.png?m&format=v2 | feh - -Z";
              listen_cmd = "${weather-listen}";
            }
            {
              name = "CalendarMeetings";
              icon = "󰃭";
              command = "xdg-open https://calendar.google.com";
              listen_cmd = "/home/jevin/.config/nixpkgs/waybar/polybar/ashell-calendar.sh";
              alert = "urgent";
            }
            {
              name = "TimeTagger";
              icon = "󱎫";
              command = "xdg-open https://timetagger.jevy.org";
              listen_cmd = "${timetagger-listen}";
            }
          ];
          workspaces = {
            visibility_mode = "MonitorSpecificExclusive";
            enable_workspace_filling = false;
          };
          # On-screen display for volume. ashell only shows the OSD for changes
          # made through its IPC (`ashell msg volume-up` etc.), so the Hyprland
          # volume keys are routed through `ashell msg` — see
          # modules/desktop/hyprland.nix. Brightness intentionally stays on the
          # cursor-aware/DDC brightnessAdjust script, so it gets no OSD.
          osd = {
            enabled = true;
            timeout = 1500;
            show_volume_percentage = true;
          };
          # ashell's [settings] table. volume_step matches the previous
          # `pamixer -i/-d 10` increment.
          settings = {
            volume_step = 10;
          };
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
          # Block startup until NetworkManager's D-Bus name is available —
          # ashell's network service doesn't retry on ServiceUnknown, so a
          # race during rebuild leaves WiFi/Bluetooth widgets missing.
          ExecStartPre = "${pkgs.networkmanager}/bin/nm-online -s -q -t 30";
          RestartSec = "2s";
        };
      };

      # See the tray-watchdog comment above for why this exists.
      systemd.user.services.ashell-tray-watchdog = {
        Unit = {
          Description = "Restart ashell when its tray D-Bus watcher stops answering";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          # `busctl --user` needs the session bus address; user units reliably
          # get XDG_RUNTIME_DIR (%t) but not always DBUS_SESSION_BUS_ADDRESS.
          Environment = "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus";
          ExecStart = "${tray-watchdog}";
        };
      };

      systemd.user.timers.ashell-tray-watchdog = {
        Unit.Description = "Probe ashell's tray D-Bus watcher every minute";
        Timer = {
          OnCalendar = "minutely";
          Persistent = false;
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };

      # Calendar notification service - checks gcalcli agenda every minute
      # with file-based dedup and tiered urgency (18m, 15m, 10m, 5m, now)
      systemd.user.services.gcal-notify = {
        Unit = {
          Description = "Google Calendar notification check";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          Environment = "PATH=${pkgs.gcalcli}/bin:${pkgs.libnotify}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gawk}/bin:${pkgs.findutils}/bin";
          ExecStart = "${pkgs.bash}/bin/bash /home/jevin/.config/nixpkgs/waybar/polybar/gcal-notify.sh";
        };
      };

      systemd.user.timers.gcal-notify = {
        Unit.Description = "Run Google Calendar notifications every minute";
        Timer = {
          OnCalendar = "minutely";
          Persistent = true;
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    };
}
