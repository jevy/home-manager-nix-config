# GridTracker: live WSJT-X decode map showing stations, grids, and DXCC status
# Receives WSJT-X primary UDP directly on :2237
# Runs inside the ham radio VNC desktop (wsjtx module), not as its own service
#
# GridTracker is an NW.js (Chromium) app whose renderer leaks ~150 MB/day —
# left running in the persistent xrdp session it grew to ~6 GB over 29 days
# and tripped NodeMemoryHighUtilization on this 8 GB box. It's launched
# manually from the XFCE menu (autostart is stripped in remote-desktop.nix),
# so there's no systemd unit to cap. A nightly kill bounds the leak to ~24h
# of growth; relaunch from the RDP menu when you next want the map. This
# mirrors the wlgate-restart workaround in modules/services/wlgate.nix.
{ inputs, ... }:
{
  flake.modules.nixos.gridtracker =
    { pkgs, lib, config, ... }:
    {
      environment.systemPackages = [ pkgs.gridtracker ];

      # Nightly kill of the GridTracker process tree to reclaim leaked memory.
      systemd.timers.gridtracker-restart = {
        description = "Nightly kill of leaky GridTracker (NW.js renderer)";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 04:00:00";
          Persistent = true;
          Unit = "gridtracker-restart.service";
        };
      };

      systemd.services.gridtracker-restart = {
        description = "Kill GridTracker to reclaim leaked memory";
        serviceConfig = {
          Type = "oneshot";
          # `[g]ridtracker` matches the running app but NOT this command's own
          # argv. Plain `gridtracker` made `pkill -f` SIGTERM its own bash shell
          # (whose argv contains the pattern) before `|| true` could run, so the
          # unit died by signal and reported failure every night.
          # `|| true` still absorbs pkill's exit 1 when GridTracker isn't running.
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.procps}/bin/pkill -f [g]ridtracker || true'";
        };
      };
    };
}
