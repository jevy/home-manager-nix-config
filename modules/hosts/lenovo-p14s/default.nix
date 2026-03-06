# Lenovo ThinkPad P14s Gen 6 AMD host definition
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos."lenovo-p14s".module =
    { pkgs, lib, ... }:
    {
      imports = [
        # Hardware
        ../../../nixos/lenovo-p14s-hardware-configuration.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen5
        nixos.lenovoP14sHardware

        # Shared Linux desktop base
        nixos.linuxDesktopBase
      ];

      networking.hostName = "lenovo-p14s";

      # LUKS
      boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/93f39771-d83e-4b78-baa2-13c6f7f921f1";

      # Btrfs, not ZFS (override shared docker module)
      virtualisation.docker.storageDriver = lib.mkForce "btrfs";
      boot.supportedFilesystems = lib.mkForce [ "btrfs" ];

      # === TEMPORARY: disable services to isolate boot issue ===
      virtualisation.docker.enable = lib.mkForce false;
      virtualisation.libvirtd.enable = lib.mkForce false;
      programs.hyprland.enable = lib.mkForce false;
      services.greetd.enable = lib.mkForce false;
      programs.regreet.enable = lib.mkForce false;
      services.tailscale.enable = lib.mkForce false;
      services.fprintd.enable = lib.mkForce false;

      home-manager.users.jevin = {
        # P14s OLED monitor (2880x1800 at 120Hz, scale 2)
        wayland.windowManager.hyprland.settings.monitor = lib.mkForce "eDP-1,2880x1800@120,0x0,2";

        # Disable Hyprland in home-manager too
        wayland.windowManager.hyprland.enable = lib.mkForce false;

        # AMD GPU session variables
        home.sessionVariables = {
          LIBVA_DRIVER_NAME = "radeonsi";
          __GLX_VENDOR_LIBRARY_NAME = "mesa";
        };
      };
    };
}
