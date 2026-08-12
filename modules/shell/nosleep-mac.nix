# nosleep (macOS): temporarily block system sleep for a fixed duration.
#
# The darwin counterpart to modules/shell/nosleep.nix, same CLI so muscle
# memory carries between machines. Where the Linux one holds a logind
# inhibitor via a transient systemd unit, this backgrounds Apple's own
# `caffeinate` with its built-in `-t` timeout and tracks the pid.
#
# Assertions taken: `-i` (no idle system sleep) + `-s` (no system sleep;
# AC-power only, per caffeinate(8)). Deliberately NOT `-d`, so the display
# still sleeps and locks on the normal schedule — matching the Linux
# module, which inhibits sleep but not idle.
#
# Caveat with no macOS equivalent: closing the lid still sleeps the machine.
# Clamshell sleep is not an assertion caffeinate can hold off, so unlike
# Linux's handle-lid-switch inhibitor there is nothing to block here.
#
# Usage:
#   nosleep 1h        # block sleep for 1 hour
#   nosleep 30m       # ...for 30 minutes
#   nosleep 90        # bare number = minutes
#   nosleep status    # show whether active + time remaining
#   nosleep off       # cancel now, re-enable sleep
{ ... }:
{
  flake.modules.homeManager.nosleepMac =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "nosleep";
          runtimeInputs = with pkgs; [ coreutils ];
          text = ''
            STATE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/nosleep"
            PID_FILE="$STATE_DIR/pid"
            DEADLINE_FILE="$STATE_DIR/deadline"

            usage() {
              cat <<HELP
            Usage: nosleep <duration|status|off>

            Block system sleep for a fixed duration. The display still sleeps
            and locks normally — only idle/system sleep is held off. Closing the
            lid still sleeps the machine (macOS allows no override).

              nosleep 1h        Block sleep for 1 hour
              nosleep 30m       ...for 30 minutes
              nosleep 45s       ...for 45 seconds
              nosleep 90        Bare number = minutes
              nosleep status    Show active state and time remaining
              nosleep off       Cancel now and re-enable sleep
            HELP
            }

            # Parse a single-token duration (1h / 30m / 45s / bare-minutes) to
            # seconds. The digit check has to come after the suffix is stripped
            # and before any arithmetic: "bogus" ends in s, and $(( bogu )) under
            # `set -u` aborts the script instead of returning a clean failure.
            parse_duration() {
              local in="$1" n unit
              case "$in" in
                *h) n=''${in%h}; unit=3600 ;;
                *m) n=''${in%m}; unit=60 ;;
                *s) n=''${in%s}; unit=1 ;;
                *)  n="$in";     unit=60 ;;
              esac
              case "$n" in
                ""|*[!0-9]*) return 1 ;;
              esac
              printf '%s' "$(( n * unit ))"
            }

            # Pretty-print a seconds count as 1h05m / 5m / 42s.
            fmt_remaining() {
              local s="$1" h m
              h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
              if [ "$h" -gt 0 ]; then printf '%dh%02dm' "$h" "$m"
              elif [ "$m" -gt 0 ]; then printf '%dm' "$m"
              else printf '%ds' "$s"; fi
            }

            # True only if the recorded pid is still a live caffeinate — a bare
            # `kill -0` would be fooled by pid reuse.
            is_active() {
              local pid
              [ -f "$PID_FILE" ] || return 1
              pid=$(cat "$PID_FILE") || return 1
              [ -n "$pid" ] || return 1
              # `-o command=` rather than `comm=`: ps truncates columns to fit,
              # and caffeinate sits early enough in the command line to survive it.
              case "$(/bin/ps -p "$pid" -o command= 2>/dev/null)" in
                *caffeinate*) return 0 ;;
                *) return 1 ;;
              esac
            }

            notify() {
              /usr/bin/osascript -e "display notification \"$2\" with title \"nosleep\" subtitle \"$1\"" >/dev/null 2>&1 || true
            }

            do_status() {
              if is_active; then
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
              if is_active; then
                kill "$(cat "$PID_FILE")" 2>/dev/null || true
              fi
              rm -f "$PID_FILE" "$DEADLINE_FILE"
              notify "Sleep re-enabled" "System can sleep normally."
            }

            case "''${1:-}" in
              ""|-h|--help|help) usage; exit 0 ;;
              status) do_status; exit 0 ;;
              off|cancel|stop) do_off; exit 0 ;;
            esac

            sec=$(parse_duration "$1") || { echo "nosleep: invalid duration: $1" >&2; usage >&2; exit 1; }
            if [ "$sec" -le 0 ]; then echo "nosleep: duration must be > 0" >&2; exit 1; fi

            mkdir -p "$STATE_DIR"

            # Replace any running instance so the timer restarts cleanly.
            if is_active; then
              kill "$(cat "$PID_FILE")" 2>/dev/null || true
            fi

            end=$(( $(date +%s) + sec ))

            # Detached so it outlives this shell and the terminal it ran in;
            # caffeinate's own -t exits it at the deadline, no cleanup needed.
            /usr/bin/caffeinate -i -s -t "$sec" >/dev/null 2>&1 &
            pid=$!
            disown "$pid" 2>/dev/null || true

            echo "$pid" > "$PID_FILE"
            echo "$end" > "$DEADLINE_FILE"

            notify "Sleep blocked" \
              "Won't sleep for $(fmt_remaining "$sec") (until $(date -d "@$end" '+%H:%M')). 'nosleep off' to cancel."
            echo "nosleep active for $(fmt_remaining "$sec") (until $(date -d "@$end" '+%H:%M'))."
          '';
        })
      ];
    };
}
