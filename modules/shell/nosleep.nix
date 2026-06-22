# nosleep: temporarily block system suspend for a fixed duration.
#
# Holds a logind "block" inhibitor on sleep + lid-switch via a transient
# systemd --user unit, so the machine won't suspend (the hypridle 600s
# `systemctl suspend` and lid-close suspend defined in modules/desktop/
# hyprland.nix are both held off). It deliberately does NOT inhibit `idle`,
# so the screen still blanks and locks on the normal hypridle timeouts —
# only suspend is suppressed.
#
# Usage:
#   nosleep 1h        # block suspend for 1 hour
#   nosleep 30m       # ...for 30 minutes
#   nosleep 90        # bare number = minutes
#   nosleep status    # show whether active + time remaining
#   nosleep off       # cancel now, re-enable suspend
{ ... }:
{
  flake.modules.homeManager.nosleep =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "nosleep";
          runtimeInputs = with pkgs; [
            systemd
            coreutils
            libnotify
          ];
          text = ''
            UNIT="nosleep.service"
            DEADLINE_FILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nosleep.deadline"

            usage() {
              cat <<HELP
            Usage: nosleep <duration|status|off>

            Block system suspend for a fixed duration. The screen still blanks
            and locks normally — only suspend (and lid-close suspend) are held off.

              nosleep 1h        Block suspend for 1 hour
              nosleep 30m       ...for 30 minutes
              nosleep 45s       ...for 45 seconds
              nosleep 90        Bare number = minutes
              nosleep status    Show active state and time remaining
              nosleep off       Cancel now and re-enable suspend
            HELP
            }

            # Parse a single-token duration (1h / 30m / 45s / bare-minutes) to seconds.
            parse_duration() {
              local in="$1"
              case "$in" in
                *h) printf '%s' "$(( ''${in%h} * 3600 ))" ;;
                *m) printf '%s' "$(( ''${in%m} * 60 ))" ;;
                *s) printf '%s' "$(( ''${in%s} ))" ;;
                *[!0-9]*) return 1 ;;
                *) printf '%s' "$(( in * 60 ))" ;;
              esac
            }

            # Pretty-print a seconds count as 1h05m / 5m / 42s.
            fmt_remaining() {
              local s="$1" h m
              h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
              if [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
              elif [ "$m" -gt 0 ]; then printf '%dm' "$m"
              else printf '%ds' "$s"; fi
            }

            do_status() {
              if systemctl --user is-active --quiet "$UNIT"; then
                if [ -f "$DEADLINE_FILE" ]; then
                  local end now rem
                  end=$(cat "$DEADLINE_FILE"); now=$(date +%s); rem=$(( end - now ))
                  [ "$rem" -lt 0 ] && rem=0
                  echo "nosleep active — $(fmt_remaining "$rem") remaining (until $(date -d "@$end" '+%H:%M'))"
                else
                  echo "nosleep active"
                fi
              else
                echo "nosleep inactive"
              fi
            }

            do_off() {
              systemctl --user stop "$UNIT" 2>/dev/null || true
              systemctl --user reset-failed "$UNIT" 2>/dev/null || true
              rm -f "$DEADLINE_FILE"
              notify-send -a nosleep "Suspend re-enabled" "System can sleep normally."
            }

            case "''${1:-}" in
              ""|-h|--help|help) usage; exit 0 ;;
              status) do_status; exit 0 ;;
              off|cancel|stop) do_off; exit 0 ;;
            esac

            sec=$(parse_duration "$1") || { echo "nosleep: invalid duration: $1" >&2; usage >&2; exit 1; }
            if [ "$sec" -le 0 ]; then echo "nosleep: duration must be > 0" >&2; exit 1; fi

            # Replace any running instance so the timer restarts cleanly.
            systemctl --user stop "$UNIT" 2>/dev/null || true
            systemctl --user reset-failed "$UNIT" 2>/dev/null || true

            end=$(( $(date +%s) + sec ))
            echo "$end" > "$DEADLINE_FILE"

            systemd-run --user --quiet \
              --unit="$UNIT" \
              --description="nosleep: suspend blocked until $(date -d "@$end" '+%H:%M')" \
              --property=RuntimeMaxSec="$sec" \
              --property=ExecStopPost="${pkgs.coreutils}/bin/rm -f $DEADLINE_FILE" \
              systemd-inhibit \
                --what=sleep:handle-lid-switch \
                --why=nosleep \
                --mode=block \
                sleep infinity

            notify-send -a nosleep "Suspend blocked" \
              "Won't sleep for $(fmt_remaining "$sec") (until $(date -d "@$end" '+%H:%M')). 'nosleep off' to cancel."
            echo "nosleep active for $(fmt_remaining "$sec") (until $(date -d "@$end" '+%H:%M'))."
          '';
        })
      ];
    };
}
