# Music making tools (yabridge, bitwig, etc.)
{ ... }:
{
  flake.modules.homeManager.music =
    { pkgs, ... }:
    let
      bitwig-scaled = pkgs.writeShellScriptBin "bitwig-scaled" ''
        export _JAVA_OPTIONS='-Dsun.java2d.uiScale=2.0'
        export DISPLAY=:0
        exec ${pkgs.bitwig-studio}/bin/bitwig-studio "$@"
      '';
    in
    {
      home.packages = with pkgs; [
        bitwig-studio
        bitwig-scaled

        yabridge
        yabridgectl

        # Wine needed for yabridge (Windows VST bridge)
        # For Wine in wayland, just make the screen scaling to 1
        # and display position to 0,0
        wineWow64Packages.unstableFull
      ];
    };
}
