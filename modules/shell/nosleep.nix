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
#
# Expiry re-arms hypridle. hypridle runs each listener's on-timeout once
# per idle stretch: if its 600s `systemctl suspend` lands while nosleep
# blocks it, the call fails and hypridle won't try again until input
# resets the idle clock. Walk away with nosleep active and the machine
# stays awake after expiry until the battery dies (happened 2026-10-10:
# suspend refused at 21:18, nosleep expired 21:21, critical-battery
# poweroff at 02:41). So when the unit stops by timeout, restart hypridle
# to restart its timers; still idle -> suspend 600s later. `nosleep off`
# (SERVICE_RESULT=success) skips this: you're at the keyboard.
{ ... }:
{
  flake.modules.homeManager.nosleep =
    { pkgs, ... }:
    let
      # ExecStopPost of the transient unit. Runs under the user manager, whose
      # environment has PATH (hyprctl) and HYPRLAND_INSTANCE_SIGNATURE.
      onStop = pkgs.writeShellScript "nosleep-on-stop" ''
        ${pkgs.coreutils}/bin/rm -f "$1"
        [ "''${SERVICE_RESULT:-}" = timeout ] || exit 0
        # try-restart: no-op if hypridle isn't running. --no-block: don't wait
        # on another unit's job from inside this unit's stop.
        ${pkgs.systemd}/bin/systemctl --user --no-block try-restart hypridle.service
        # The fresh hypridle has no "idled" state for the dpms listener, so its
        # on-resume won't fire and a key press wouldn't wake a blanked screen
        # (Hyprland's *_enables_dpms are off). Turn it on now; the new
        # instance blanks it again 180s later.
        hyprctl dispatch dpms on >/dev/null 2>&1 || true
      '';
    in
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
              --property=ExecStopPost="${onStop} $DEADLINE_FILE" \
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
