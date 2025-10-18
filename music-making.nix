{
  config,
  pkgs,
  libs,
  ...
}: {
  home.packages = with pkgs; [
    yabridge
    yabridgectl
    qjackctl
    qtractor
    patchage
    bitwig-studio
    # wineWowPackages.staging # Kinda works
    # winePackages.waylandFull # No
    # wineWow64Packages.waylandFull # No
    # wine-wayland # No
    # wine64 # No
    # wineWow64Packages.stagingFull # No

    # For Wine in wayland, just make the screen scaling to 1
    # and display position to 0,0
    wineWowPackages.unstableFull
    qjackctl
  ];
}
