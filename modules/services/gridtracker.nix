# GridTracker: live WSJT-X decode map showing stations, grids, and DXCC status
# Receives WSJT-X primary UDP directly on :2237
# Runs inside the ham radio VNC desktop (wsjtx module), not as its own service
{ inputs, ... }:
{
  flake.modules.nixos.gridtracker =
    { pkgs, lib, config, ... }:
    {
      environment.systemPackages = [ pkgs.gridtracker ];
    };
}
