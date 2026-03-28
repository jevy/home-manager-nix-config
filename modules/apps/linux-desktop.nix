# Linux desktop applications and tools
{ inputs, ... }:
{
  flake.modules.homeManager.linuxDesktop =
    { config, pkgs, ... }:
    let
      llmWithPlugins = pkgs.python313.withPackages (ps: [
        ps.llm
        ps.llm-cmd
        ps.llm-openrouter
      ]);
      wrappedLlm = pkgs.symlinkJoin {
        name = "llm-wrapped";
        paths = [ llmWithPlugins ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/llm \
            --run 'export OPENAI_API_KEY=$(cat ${config.sops.secrets.openai_api_key.path} 2>/dev/null || true)' \
            --run 'export OPENROUTER_KEY=$(cat ${config.sops.secrets.openrouter_api_key.path} 2>/dev/null || true)'
        '';
      };
    in
    {
      home.packages = with pkgs; [
        hyprpaper
        upower
        wrappedLlm
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
        nmap
        immich-go
        orca-slicer
        kdePackages.kdenlive
        qbittorrent
      ];

      programs.radio-active.enable = true;
      programs.radio-cli.enable = true;
    };
}
