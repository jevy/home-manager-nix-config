{
  config,
  pkgs,
  libs,
  ...
}: {
  imports = [
    ./desktop-linux-common.nix
  ];

  home.packages = with pkgs; [
    synology-drive-client
    # ruby
    # gnumake
    # gcc
    # bundix
    # # python-qt
    kubernetes-helm
    dropbox
    # arduino
    hugo
    steam
    gcalcli

    # unstable.bambu-studio
    # unstable.orca-slicer
    rpi-imager
    sunpaper
    newsflash
    qflipper
    jellyfin-media-player
    zotero
    openscad
    cc2538-bsl

    glxinfo
    vulkan-tools

    protonup-qt
    steamtinkerlaunch
    unstable.llm
    fluxcd
    unstable.fluxcd-operator
    kustomize
    mqttx
    mqttui
    unstable.aider-chat
    hypnotix
    # unstable.qdmr
    calibre
    unstable.talosctl
    kicad
    unstable.renovate
    esptool
    freecad-wayland
    img2pdf
  ];

  wayland.windowManager.sway = {
    config = {
      startup = [
        {command = "${pkgs.synology-drive-client}/bin/synology-drive";}
      ];
    };
  };
}
