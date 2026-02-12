# Framework laptop host definition (fully dendritic)
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
  inherit (config.flake) overlays;
in
{
  configurations.nixos.framework.module =
    { pkgs, lib, ... }:
    {
      imports = [
        # Hardware
        ../../../nixos/hardware-configuration.nix
        inputs.nixos-hardware.nixosModules.framework-12th-gen-intel

        # Feature modules (dendritic)
        nixos.zsh
        nixos.nix
        nixos.user
        nixos.stylix
        nixos.audio
        nixos.fonts
        nixos.hyprland
        nixos.tailscale
        nixos.kanata
        nixos.docker
        nixos.frameworkHardware
        nixos.boot
        nixos.network
        nixos.printing
        nixos.onepassword

        # External modules
        inputs.musnix.nixosModules.musnix
        inputs.home-manager.nixosModules.home-manager
      ];

      nixpkgs.hostPlatform = "x86_64-linux";
      networking.hostName = "framework";
      networking.hostId = "6a7f48db";

      # Musnix for audio
      musnix.enable = true;
      users.users.jevin.extraGroups = [ "audio" ];

      # Nixpkgs configuration
      nixpkgs.config = {
        allowUnfree = true;
        allowBroken = true;
        segger-jlink.acceptLicense = true;
        permittedInsecurePackages = [
          "electron-25.9.0"
          "libsoup-2.74.3"
          "qtwebengine-5.15.19"
        ];
      };
      nixpkgs.overlays = [
        overlays.volsync
        overlays.tailscale
        overlays.claudeCode
        overlays.hyprland
        overlays.kdenlive
      ];

      # NFS mount (host-specific)
      fileSystems."/mnt/synology-backup" = {
        device = "192.168.1.187:/volume1/proxmox";
        fsType = "nfs";
        options = [
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=600"
        ];
      };

      system.stateVersion = "24.11";

      # Home-manager integration
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        users.jevin = {
          imports = [
            homeManager.zsh
            homeManager.ghostty
            homeManager.sops
            homeManager.git
            homeManager.backup
            homeManager.cliBase
            homeManager.cliLinux
            homeManager.audio
            homeManager.nixvim
            homeManager.mcp
            homeManager.hyprland
            homeManager.sway
            homeManager.mutt
            homeManager.music
            homeManager.spicetify
            homeManager.nixvimVscode
            homeManager.desktopApps
            homeManager.linuxDesktop
            homeManager.ashell
            homeManager.hyprSession

            inputs.typing-analysis.homeManagerModules.default
          ];

          home.stateVersion = "24.11";

          home.keyboard = {
            layout = "us";
            variant = "qwerty";
            options = [ "ctrl:nocaps" ];
          };

          # Typing analysis
          services.typing-analysis.enable = true;

          # Framework Intel iGPU specific
          home.sessionVariables = {
            LIBVA_DRIVER_NAME = "iHD";
            __GLX_VENDOR_LIBRARY_NAME = "mesa";
            WLR_NO_HARDWARE_CURSORS = "1";
          };
        };
      };
    };
}
