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

    bambu-studio
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
    llm
    fluxcd
    unstable.fluxcd-operator
    kustomize
    mqttx
    mqttui
    unstable.aider-chat
    hypnotix
    unstable.qdmr
    calibre
  ];

  wayland.windowManager.sway = {
    config = {
      startup = [
        {command = "${pkgs.synology-drive-client}/bin/synology-drive";}
      ];
    };
  };
}
