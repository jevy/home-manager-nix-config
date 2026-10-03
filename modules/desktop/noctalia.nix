# Noctalia v5: bar, notifications, launcher, OSD and lock screen for Hyprland.
# Active only when desktopShell = "noctalia" (modules/desktop/desktop-shell.nix).
# Design: docs/superpowers/specs/2026-10-03-noctalia-shell-design.md
#
# The HM-generated systemd.user.services.noctalia starts from
# graphical-session.target (home-manager's default target for
# `programs.noctalia.systemd.enable`), which UWSM activates. See
# modules/desktop/hyprland.nix for why that's the right target here.
#
# CONFIG DRIFT: anything changed in Noctalia's settings GUI is written to
# ~/.local/state/noctalia/settings.toml, and that file WINS over the
# config.toml generated here. "I changed it in Nix and nothing happened" means
# the GUI overrode it. Check with:
#   cat ~/.local/state/noctalia/settings.toml
# Keep Nix as the source of truth: copy keepers in here, then delete the
# override from the state file. Rebuilds never touch the state file.
#
# STRICT CHECK: `noctalia config validate` only WARNS on problems (unknown
# key, or a plugin/widget type that didn't load) and exits 0 regardless
# (measured on 5.1.0), so home-manager's checkConfig lets both through.
# Measured: an out-of-range plugin_api produces a passing validate with
# `WRN [plugins] ignoring plugin ...` plus `WARN widget.X: unrecognized
# widget type ...` and a `✓ Config is valid (N warning(s))` summary, which
# silently drops that widget from the bar. strictConfig below fails the
# build on ANY warning line (WARN/WRN, or a nonzero "warning(s)" count), not
# just "unknown setting".
#
# Not here on purpose:
#   - wallpaper: hyprpaper plus Jevin's art tool own it; Noctalia draws none.
#   - colors: stylix.targets.noctalia writes the palette from base16.
#   - Frigate's 256px notification icons (mako had them): Noctalia has no
#     per-app icon size. Known loss.
{ ... }:
{
  # Lock screen PAM. Noctalia's lock authenticates through the hard-coded
  # "login" PAM service (noctalia-dev/noctalia#3277, open 2026-10-03). With
  # pam_fprintd in that stack a typed password waits ~30s for a finger first.
  # The lock drives fprintd over D-Bus itself, so fingerprint unlock still
  # works. Cost: no fingerprint at a text-console (TTY) login. greetd already
  # has it off (modules/desktop/hyprland.nix).
  flake.modules.nixos.noctaliaLock =
    { config, lib, ... }:
    lib.mkIf (config.desktopShell == "noctalia") {
      security.pam.services.login.fprintAuth = false;
    };

  flake.modules.homeManager.noctalia =
    { config, lib, pkgs, ... }:
    let
      # Same loop as ashell.nix's weather-listen; duplicated until the legacy
      # stack is deleted.
      weatherListen = pkgs.writeShellScript "noctalia-weather-listen" ''
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

      # Rerun a listen script forever. Whenever it exits, say so in the bar
      # (alt = error renders red) before retrying, so stale text never sits
      # there unmarked.
      restartLoop =
        name: cmd:
        pkgs.writeShellScript "noctalia-${lib.toLower name}-stream" ''
          while true; do
            ${cmd}
            echo '{"text": "${name} unavailable", "alt": "error"}'
            sleep 15
          done
        '';

      calendarStream = restartLoop "Calendar" "/home/jevin/.config/nixpkgs/waybar/polybar/ashell-calendar.sh";
      weatherStream = restartLoop "Weather" "${weatherListen}";

      calendarClick = "${pkgs.xdg-utils}/bin/xdg-open https://calendar.google.com";
      # Click on the bar weather opens Noctalia's Weather tab (Open-Meteo
      # 6-day forecast), matching how the built-in widgets behave.
      weatherClick = "${pkgs.noctalia}/bin/noctalia msg panel-toggle control-center weather";
      # The old ashell click (wttr.in picture in feh), kept for reuse: swap it
      # into the weather substitute below to bring it back.
      # URL quoted: unquoted, sh reads `&` as "background this".
      weatherClickWttr = pkgs.writeShellScript "noctalia-weather-click" ''
        ${pkgs.wget}/bin/wget -qO - 'http://wttr.in/.png?m&format=v2' | ${pkgs.feh}/bin/feh - -Z
      '';

      # One read-only plugin directory, registered below as a "path" source
      # (5.1.0 docs: "ideal for Nix-managed plugins"). Both widgets share
      # stream-widget.luau; luau-compile fails the build on a syntax error.
      plugins = pkgs.runCommand "noctalia-plugins-jevin" { nativeBuildInputs = [ pkgs.luau ]; } ''
        mkdir -p $out/calendar $out/weather
        cp ${./noctalia-plugins/calendar/plugin.toml} $out/calendar/plugin.toml
        cp ${./noctalia-plugins/weather/plugin.toml} $out/weather/plugin.toml

        substitute ${./noctalia-plugins/stream-widget.luau} $out/calendar/widget.luau \
          --replace-fail @name@ Calendar \
          --replace-fail @glyph@ calendar \
          --replace-fail @stream@ ${calendarStream} \
          --replace-fail @click@ "${calendarClick}"

        substitute ${./noctalia-plugins/stream-widget.luau} $out/weather/widget.luau \
          --replace-fail @name@ Weather \
          --replace-fail @glyph@ "" \
          --replace-fail @stream@ ${weatherStream} \
          --replace-fail @click@ "${weatherClick}"

        for f in $out/*/widget.luau; do
          luau-compile --null "$f"
        done
      '';

      rawConfig = (pkgs.formats.toml { }).generate "noctalia-config.toml" config.programs.noctalia.settings;
      strictConfig =
        pkgs.runCommand "noctalia-config-strict.toml" { nativeBuildInputs = [ pkgs.noctalia ]; }
          ''
            export HOME=$TMPDIR
            noctalia config validate ${rawConfig} 2>&1 | tee validate.log
            if grep -qE '^(WARN|WRN)|warning\(s\)' validate.log; then
              echo "noctalia: validate reported warning(s) in config.toml, see above" >&2
              exit 1
            fi
            cp ${rawConfig} $out
          '';
    in
    lib.mkIf (config.desktopShell == "noctalia") {
      # ashell.nix provided notify-send via libnotify; Noctalia doesn't pull
      # it in itself, and some scripts (gcal-notify, brightness OSD helpers)
      # still shell out to notify-send regardless of which shell is active.
      home.packages = [ pkgs.libnotify ];

      programs.noctalia = {
        enable = true;
        package = pkgs.noctalia;
        systemd.enable = true;
        # Replaced by strictConfig (see header).
        checkConfig = false;

        settings = {
          wallpaper.enabled = false;

          # stylix.polarity is "either" (measured), and stylix's noctalia
          # target maps anything but "dark" to theme.mode = "light". That
          # would put a light shell over the dark gruvbox-material palette,
          # so force dark here regardless of stylix.polarity.
          theme.mode = lib.mkForce "dark";

          lockscreen.fingerprint = true;

          # Close to Noctalia's own default layout: a quiet bar of icons, with
          # details in the Control Center panel (media, weather forecast,
          # notifications, audio). The meetings widget is ours and hides
          # itself unless a meeting is within the hour.
          bar.default = {
            start = [ "workspaces" ];
            center = [
              "clock"
              "meetings"
            ];
            end = [
              "media"
              "weather_script"
              "tray"
              "notifications"
              "volume"
              "battery"
              "control-center"
            ];
          };

          widget = {
            meetings.type = "jevin/calendar:meetings";
            # Built-in weather widget (Open-Meteo) only shows current
            # conditions, so the bar uses our script (now + next forecast)
            # instead. Kept configured for reuse: add "weather" to a bar list.
            weather.show_condition = false;
            # OpenWeatherMap stream: current and next-forecast temps, like the
            # ashell bar had. Click opens the Weather tab.
            weather_script.type = "jevin/weather:forecast";
            # Tray icons live behind one button that opens a drawer panel.
            tray.drawer = true;
            # No "Nothing Playing" placeholder; it appears with a player.
            media.hide_when_no_media = true;
            # Red only when muted (Noctalia's default; stated explicitly
            # because a dimmed mute color was tried and rejected). Volume
            # level never changes the color.
            volume.mute_color = "error";
            clock = {
              type = "clock";
              # Verbatim ashell tempo.clock_format. Noctalia accepts bare
              # strftime, and %l (space-padded 12-hour) is supported.
              format = "%a %d %b %l:%M %p";
            };
          };

          weather = {
            enabled = true;
            unit = "metric";
          };
          # Ottawa by coordinates. `address = "Ottawa, ON"` failed on 5.1.0:
          # api.noctalia.dev/geocode returned 404 and the bar showed
          # "No location" (measured 2026-10-03). One decimal (~10 km) is
          # plenty for weather and keeps the committed location city-level.
          location = {
            auto_locate = false;
            latitude = 45.4;
            longitude = -75.7;
          };

          # mako used `invisible = 1` for these. Toasts off; history keeps them.
          notification = {
            filter_order = [
              "spotify"
              "slack"
              "obsidian"
              "cloud_drive"
            ];
            filter = {
              spotify = {
                match = "Spotify";
                show_toast = false;
              };
              slack = {
                match = "Slack";
                show_toast = false;
              };
              obsidian = {
                match = "Obsidian";
                show_toast = false;
              };
              cloud_drive = {
                match = "cloud-drive-ui";
                show_toast = false;
              };
            };
          };

          plugins = {
            enabled = [
              "jevin/calendar"
              "jevin/weather"
            ];
            source = [
              {
                name = "jevin";
                kind = "path";
                location = "${plugins}";
                enabled = true;
              }
            ];
          };
        };
      };

      xdg.configFile."noctalia/config.toml".source = lib.mkForce strictConfig;

      # The HM-generated unit is Restart=on-failure with its default
      # RestartSec. Noctalia answers logind's Lock signal itself while it's
      # up; hypridle's lock_cmd (modules/desktop/hyprland.nix) only falls
      # back to hyprlock while Noctalia is down, so a quick restart shortens
      # that unlocked window after a crash.
      systemd.user.services.noctalia.Service.RestartSec = 2;
    };
}
