# Lenovo ThinkPad P14s Gen 6 AMD host definition
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
  inherit (config.flake) overlays;
in
{
  configurations.nixos."lenovo-p14s".module =
    { pkgs, lib, ... }:
    {
      imports = [
        # Hardware
        ../../../nixos/lenovo-p14s-hardware-configuration.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen5

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
        nixos.lenovoP14sHardware
        nixos.boot
        nixos.network
        nixos.printing
        nixos.onepassword

        # External modules
        inputs.home-manager.nixosModules.home-manager
      ];

      nixpkgs.hostPlatform = "x86_64-linux";
      networking.hostName = "lenovo-p14s";

      # LUKS + Btrfs
      boot.initrd.luks.devices.root = {
        device = "/dev/nvme0n1p1";
        preLVM = true;
      };

      # Nixpkgs configuration
      nixpkgs.config = {
        allowUnfree = true;
        allowBroken = true;
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
        overlays.mcpServers
      ];

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
            homeManager.spicetify
            homeManager.nixvimVscode
            homeManager.clipboard
            homeManager.desktopApps
            homeManager.linuxDesktop
            homeManager.ashell
            homeManager.hyprSession
            homeManager.beads
            homeManager.claudeCode
            homeManager.opencode
            homeManager.qmd
            homeManager.timetagger
            homeManager.taskArchiver

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

          # P14s OLED monitor (2880x1800 at 120Hz, scale 2)
          wayland.windowManager.hyprland.settings.monitor = lib.mkForce "eDP-1,2880x1800@120,0x0,2";

          # AMD GPU session variables
          home.sessionVariables = {
            LIBVA_DRIVER_NAME = "radeonsi";
            __GLX_VENDOR_LIBRARY_NAME = "mesa";
          };
        };
      };
    };
}
