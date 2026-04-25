# GridTracker: live WSJT-X decode map showing stations, grids, and DXCC status
# Receives UDP from WLGate's relay on :2237
# Runs headless under Xvnc, accessible via VNC on :5943
{ inputs, ... }:
{
  flake.modules.nixos.gridtracker =
    { pkgs, lib, config, ... }:
    let
      gridtrackerWrapper = pkgs.writeShellScript "gridtracker-start" ''
        export DISPLAY=:43
        ${pkgs.tigervnc}/bin/Xvnc :43 -geometry 2880x1800 -depth 24 -SecurityTypes None -localhost 0 &
        sleep 1

        ${pkgs.openbox}/bin/openbox &
        exec ${pkgs.gridtracker}/bin/gridtracker
      '';
    in
    {
      users.users.gridtracker = {
        isSystemUser = true;
        group = "gridtracker";
        home = "/var/lib/gridtracker";
        createHome = true;
      };
      users.groups.gridtracker = { };

      systemd.services.gridtracker = {
        description = "GridTracker — WSJT-X decode map";
        after = [ "network-online.target" "wlgate.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ExecStart = gridtrackerWrapper;
          Restart = "on-failure";
          RestartSec = 10;
          User = "gridtracker";
          Group = "gridtracker";
          StateDirectory = "gridtracker";
          WorkingDirectory = "/var/lib/gridtracker";
        };
      };

      # Allow VNC access over Tailscale (Xvnc :43 = port 5943)
      networking.firewall.allowedTCPPorts = [ 5943 ];
    };
}
