# Shared base for all Linux desktop hosts
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
  inherit (config.flake) overlays;
in
{
  flake.modules.nixos.linuxDesktopBase =
    { pkgs, lib, ... }:
    {
      imports = [
        # Feature modules (dendritic)
        nixos.nix
        nixos.user
        nixos.zsh
        nixos.stylix
        nixos.audio
        nixos.fonts
        nixos.hyprland
        nixos.tailscale
        nixos.kanata
        nixos.docker
        nixos.boot
        nixos.network
        nixos.printing
        nixos.onepassword
        nixos.steam

        # External modules
        inputs.home-manager.nixosModules.home-manager
      ];

      nixpkgs.hostPlatform = "x86_64-linux";

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
        overlays.hyprland
        overlays.mcpServers
        overlays.llamaCpp
        overlays.lieer
        overlays.claudeCode
        overlays.bambuStudio
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
            homeManager.ranger
            homeManager.yazi
            homeManager.cliBase
            homeManager.cliLinux
            homeManager.audio
            homeManager.nixvim
            homeManager.mcp
            homeManager.hyprland
            homeManager.mutt
            homeManager.spicetify
            homeManager.ncspot
            homeManager.nixvimVscode
            homeManager.clipboard
            homeManager.desktopApps
            homeManager.linuxDesktop
            homeManager.ashell
            homeManager.mako
            homeManager.hyprSession
            # homeManager.beads  # disabled: vendorHash mismatch with upstream
            homeManager.ssh
            homeManager.claudeCode
            homeManager.opencode
            homeManager.qmd
            homeManager.timetagger
            homeManager.steamPlaytime
            homeManager.secondBrain
            homeManager.taskArchiver
            homeManager.taskCompletedStamp
            homeManager.taskSnapshot
            homeManager.frigateNotify
            homeManager.music

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
        };
      };
    };
}
