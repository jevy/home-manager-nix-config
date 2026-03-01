# Framework laptop host definition
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos.framework.module =
    { pkgs, lib, ... }:
    {
      imports = [
        # Hardware
        ../../../nixos/hardware-configuration.nix
        inputs.nixos-hardware.nixosModules.framework-12th-gen-intel
        nixos.frameworkHardware

        # Shared Linux desktop base
        nixos.linuxDesktopBase

        # External modules
        inputs.musnix.nixosModules.musnix
      ];

      networking.hostName = "framework";
      networking.hostId = "6a7f48db";

      # LUKS + ZFS
      boot.supportedFilesystems = [ "zfs" "nfs" ];
      boot.initrd.luks.devices.root = {
        device = "/dev/nvme0n1p1";
        preLVM = true;
      };

      # Musnix for audio
      musnix.enable = true;
      users.users.jevin.extraGroups = [ "audio" ];

      # Framework-specific nixpkgs config
      nixpkgs.config.segger-jlink.acceptLicense = true;

      # NFS mount
      fileSystems."/mnt/synology-backup" = {
        device = "192.168.1.187:/volume1/proxmox";
        fsType = "nfs";
        options = [
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=600"
        ];
      };

      # Framework Intel iGPU specific
      home-manager.users.jevin = {
        home.sessionVariables = {
          LIBVA_DRIVER_NAME = "iHD";
          __GLX_VENDOR_LIBRARY_NAME = "mesa";
          WLR_NO_HARDWARE_CURSORS = "1";
        };
      };
    };
}
