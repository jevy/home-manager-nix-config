# Ashell status bar for Hyprland
{ ... }:
{
  flake.modules.homeManager.ashell =
    { pkgs, ... }:
    let
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
