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
