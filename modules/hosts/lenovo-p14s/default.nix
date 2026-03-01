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
      boot.initrd.luks.devices.root = {
        device = "/dev/nvme0n1p1";
        preLVM = true;
      };

      home-manager.users.jevin = {
        # P14s OLED monitor (2880x1800 at 120Hz, scale 2)
        wayland.windowManager.hyprland.settings.monitor = lib.mkForce "eDP-1,2880x1800@120,0x0,2";

        # AMD GPU session variables
        home.sessionVariables = {
          LIBVA_DRIVER_NAME = "radeonsi";
          __GLX_VENDOR_LIBRARY_NAME = "mesa";
        };
      };
    };
}
