# GridTracker: live WSJT-X decode map showing stations, grids, and DXCC status
# Receives UDP from WLGate's relay on :2237
# Runs inside the ham radio VNC desktop (wsjtx module), not as its own service
{ inputs, ... }:
{
  flake.modules.nixos.gridtracker =
    { pkgs, lib, config, ... }:
    {
      environment.systemPackages = [ pkgs.gridtracker ];
    };
}
