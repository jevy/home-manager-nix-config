# Shared base for all Linux desktop hosts
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
  inherit (config.flake) overlays;
in
{
  flake.modules.nixos.linuxDesktopBase =
    { pkgs, lib, config, ... }:
    {
      imports = [
        # Feature modules (dendritic)
        nixos.nix
        nixos.user
        nixos.zsh
        nixos.nixvim
        nixos.stylix
        nixos.wallpaper
        nixos.audio
        nixos.fonts
        nixos.hyprland
        nixos.desktopShell
        nixos.noctaliaLock
        nixos.tailscale
        nixos.kanata
        nixos.docker
        nixos.boot
        nixos.network
        nixos.printing
        nixos.onepassword
        nixos.steam
        nixos.pi

        # External modules
        inputs.home-manager.nixosModules.home-manager
      ];

      nixpkgs.hostPlatform = "x86_64-linux";

      nixpkgs.config = {
        allowUnfree = true;
        allowBroken = true;
        permittedInsecurePackages = [
          "electron-25.9.0"
          "keybase-gui-6.5.1"
          "libsoup-2.74.3"
          "qtwebengine-5.15.19"
        ];
      };
      nixpkgs.overlays = [
        overlays.volsync
        overlays.mcpServers
        overlays.goobookRelaxDeps
        overlays.powerProfilesDaemonSkipCheck
        overlays.masterpdfeditorFix
      ];

      system.stateVersion = "24.11";

      # Desktop shell (modules/desktop/desktop-shell.nix). "legacy" rolls back.
      desktopShell = "noctalia";

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
            homeManager.gitSpice
            homeManager.backup
            homeManager.ranger
            homeManager.yazi
            homeManager.cliBase
            homeManager.cliLinux
            # homeManager.llmfit  # parked 2026-09-27: pkgs/llmfit-amd-igpu-gtt.patch does not apply to llmfit 1.1.16 in current nixpkgs; rebase the patch before re-enabling
            homeManager.audio
            homeManager.nixvim
            homeManager.mcp
            homeManager.flowgraph
            homeManager.hunk
            homeManager.herdr
            homeManager.tuicr
            homeManager.hyprland
            homeManager.kanata
            homeManager.mutt
            homeManager.spicetify
            homeManager.ncspot
            homeManager.clipboard
            homeManager.desktopApps
            homeManager.obsidian
            homeManager.linuxDesktop
            homeManager.desktopShell
            homeManager.noctalia
            homeManager.ashell
            homeManager.wallpaper
            homeManager.gcalNotify
            homeManager.mako
            homeManager.hyprSession
            homeManager.ssh
            homeManager.claudeCode
            homeManager.opencode
            homeManager.qmd
            homeManager.timetagger
            homeManager.steamPlaytime
            homeManager.nosleep
            homeManager.secondBrain
            homeManager.taskArchiver
            homeManager.taskCompletedStamp
            homeManager.taskSnapshot
            homeManager.frigateNotify
            homeManager.music
            homeManager.navidrome
            homeManager.pi

            inputs.typing-analysis.homeManagerModules.default
          ];

          # Mirror of the NixOS-side switch (modules/desktop/desktop-shell.nix).
          desktopShell = config.desktopShell;

          home.stateVersion = "24.11";

          home.keyboard = {
            layout = "us";
            variant = "qwerty";
            options = [ ];  # caps2esc handled by kanata
          };

          # Typing analysis
          services.typing-analysis.enable = true;
        };
      };
    };
}
