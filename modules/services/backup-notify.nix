# Tell me when a backup fails.
#
#   restic-backups-truenas-documents ─┐
#   restic-backups-truenas-mail       ├─ OnFailure ─▶ backup-failed@<unit>
#   restic-check-mail                 ─┘                   │
#                                                          ├─▶ mako notification
#                                                          └─▶ append to a log
#
# This exists because of a nine-day outage. Between 2026-09-14 and 2026-09-22
# every Documents backup failed on the resume race (see laptop-backup.nix), and
# nothing said so. `systemctl list-timers` still showed the timer healthy and
# scheduled, because a timer is healthy when it FIRES, not when the thing it
# fires succeeds. The failure was only ever visible to someone who thought to
# run `journalctl -u` on a unit they had no reason to suspect.
#
# ---------------------------------------------------------------------------
# WHY THIS DOES NOT SPAM ON RETRIES
# ---------------------------------------------------------------------------
#
# Both backup units set Restart=on-failure with 6 attempts per hour, so a single
# bad night can mean six failed starts. This fires once, not six times, because
# OnFailure activates when a unit enters the FAILED state, and a unit with
# Restart= set enters `auto-restart` rather than `failed` until its start limit
# is exhausted. So the notification means "it has given up", not "an attempt
# missed", which is the thing actually worth interrupting someone for.
#
# ---------------------------------------------------------------------------
# THE LOG IS NOT REDUNDANT WITH THE NOTIFICATION
# ---------------------------------------------------------------------------
#
# A desktop notification only exists if mako is running and someone is looking.
# These jobs run at 03:30 and 04:30, and the retry path means a failure can
# resolve itself at 06:00 while the laptop is shut. So every failure also
# appends a line to ~/.local/state/backup-failures.log, which survives being
# missed and is greppable later. The notification is the interrupt; the log is
# the record.
{ ... }:
{
  flake.modules.homeManager.backupNotify =
    { config, pkgs, ... }:
    let
      failureLog = "${config.home.homeDirectory}/.local/state/backup-failures.log";

      notifyScript = pkgs.writeShellScript "backup-failure-notify" ''
        unit="$1"

        # Last few journal lines for the failed unit, which is almost always
        # where the actual reason is. -o cat drops the timestamp/host prefix so
        # the notification body stays readable at mako's width.
        detail=$(${pkgs.systemd}/bin/journalctl --user -u "$unit" -n 20 --no-pager -o cat 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep -vE '^\+ ' \
          | ${pkgs.coreutils}/bin/tail -4)

        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname ${failureLog})"
        {
          echo "=== $(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S') $unit FAILED"
          echo "$detail"
        } >> ${failureLog}

        # -u critical so mako does not auto-dismiss it: a backup failure should
        # still be on screen whenever the laptop is next looked at.
        ${pkgs.libnotify}/bin/notify-send \
          -u critical \
          -a "Backup" \
          -i dialog-error \
          "Backup failed: $unit" \
          "$detail

        Log: ${failureLog}"
      '';
    in
    {
      # Template unit: OnFailure=backup-failed@%n.service passes the failing
      # unit's full name (including the .service suffix) as the instance.
      systemd.user.services."backup-failed@" = {
        Unit.Description = "Notify that %i failed";
        Service = {
          Type = "oneshot";
          # notify-send needs the session bus. A systemd user unit does not
          # reliably inherit DBUS_SESSION_BUS_ADDRESS from the graphical
          # session, and without it notify-send exits non-zero and the failure
          # goes unreported -- which would be a notifier that fails silently,
          # the exact problem this module exists to fix.
          Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus" ];
          ExecStart = "${notifyScript} %i";
        };
      };
    };
}
