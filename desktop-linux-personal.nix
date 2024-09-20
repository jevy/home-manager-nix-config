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
    # ansible
    gcalcli
    # # etcher

    bambu-studio
    rpi-imager
    sunpaper
    newsflash
    qflipper
    jellyfin-media-player
    zotero
    openscad
    ledfx
    cc2538-bsl

    glxinfo
    vulkan-tools

    protonup-qt
    steamtinkerlaunch
    bitwig-studio
    terraform
    llm
    talosctl
    fluxcd
    kustomize
    mqttx
    mqttui
    spotify-player
    aider-chat
  ];

  wayland.windowManager.sway = {
    config = {
      startup = [
        {command = "${pkgs.synology-drive-client}/bin/synology-drive";}
      ];
    };
  };
}
