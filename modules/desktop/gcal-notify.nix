# Google Calendar meeting-reminder notifications.
#
# Split out of ashell.nix instead of living inside its legacy-only mkIf:
# meeting reminders need to keep firing under either desktop shell, not just
# the legacy bar, so this module is always-on (no desktopShell guard).
{ ... }:
{
  flake.modules.homeManager.gcalNotify =
    { pkgs, ... }:
    {
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
