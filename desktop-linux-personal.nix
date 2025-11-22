{
  config,
  pkgs,
  libs,
  ...
}:
{
  imports = [
    ./desktop-linux-common.nix
  ];

  home.packages = with pkgs; let
    llmWithPlugins =
      unstable.python313.withPackages (ps: [
        ps.llm
        ps.llm-cmd
        ps.llm-openrouter
      ]);
  in [
    llmWithPlugins
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
    qFlipper
    # jellyfin-media-player # build broken on ffmpeg 8.0 via qtwebengine
    zotero
    openscad
    cc2538-bsl

    mesa-demos
    vulkan-tools

    protonup-qt
    steamtinkerlaunch
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

    # Radio stuff
    yewtube
    # cmus # broken build against ffmpeg 8.0
    pyradio
    mpv
    mixxx
    spotdl
  ];

  programs.radio-active.enable = true;
  programs.radio-cli.enable = true;

  wayland.windowManager.sway = {
    config = {
      startup = [
        { command = "${pkgs.synology-drive-client}/bin/synology-drive"; }
      ];
    };
  };
}
