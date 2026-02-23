# Music making tools (yabridge, bitwig, etc.)
{ ... }:
{
  flake.modules.homeManager.music =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # yabridge/yabridgectl disabled: broken upstream (32-bit Wine linking)
        # yabridge
        # yabridgectl
        qjackctl
        qtractor
        patchage
        bitwig-studio

        # For Wine in wayland, just make the screen scaling to 1
        # and display position to 0,0
        wineWow64Packages.unstableFull
      ];
    };
}
