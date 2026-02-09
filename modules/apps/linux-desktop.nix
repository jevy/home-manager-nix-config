# Linux desktop applications and tools
{ inputs, ... }:
{
  flake.modules.homeManager.linuxDesktop =
    { pkgs, ... }:
    let
      llmWithPlugins = pkgs.python313.withPackages (ps: [
        ps.llm
        ps.llm-cmd
        ps.llm-openrouter
      ]);
      claude-code-router = pkgs.callPackage ../../pkgs/claude-code-router.nix {};
      container-use = pkgs.callPackage ../../pkgs/container-use.nix {};
    in
    {
      home.packages = with pkgs; [
        hyprpaper
        upower
        llmWithPlugins
        synology-drive-client
        kubernetes-helm
        dropbox
        hugo
        gcalcli
        rpi-imager
        sunpaper
        newsflash
        qFlipper
        zotero
        openscad
        cc2538-bsl
        mesa-demos
        vulkan-tools
        protonup-qt
        fluxcd
        fluxcd-operator
        kustomize
        mqttx
        mqttui
        aider-chat
        hypnotix
        talosctl
        esptool
        freecad-wayland
        img2pdf
        yewtube
        pyradio
        mpv
        mixxx
        spotdl
        claude-code
        claude-code-router
        container-use
        nmap
        immich-go
        orca-slicer
        kdePackages.kdenlive
      ];

      programs.radio-active.enable = true;
      programs.radio-cli.enable = true;
    };
}
