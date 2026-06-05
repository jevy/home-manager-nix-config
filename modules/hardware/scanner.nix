# SANE + ScanSnap S1300 (epjitsu backend)
#
# The S1300 has no persistent firmware flash — the epjitsu backend uploads
# 1300_0C26.nal over USB on every connect. PFU/Ricoh doesn't redistribute
# it, so nixpkgs can't ship it; stevleibelt/scansnap-firmware on GitHub has
# mirrored the .nal blobs since 2017 and is what the SANE community points
# at. Pinned by commit so it's reproducible.
{ ... }:
{
  flake.modules.nixos.scanner =
    { pkgs, ... }:
    let
      scansnapFirmware = pkgs.fetchFromGitHub {
        owner = "stevleibelt";
        repo = "scansnap-firmware";
        rev = "96c3a8b2a4e4f1ccc4e5827c5eb5598084fd17c8";
        hash = "sha256-XjVc+rpQLeKXIFlTVHAC7Ah7c7kQvTs1aIl7rLaFzMY=";
      };
    in
    {
      hardware.sane.enable = true;

      users.users.jevin.extraGroups = [ "scanner" "lp" ];

      environment.systemPackages = with pkgs; [ sane-backends ];

      environment.etc."sane.d/epjitsu.conf".text = ''
        firmware ${scansnapFirmware}/1300_0C26.nal
        usb 0x04c5 0x11ed
      '';
    };
}
