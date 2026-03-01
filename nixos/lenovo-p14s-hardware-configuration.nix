# PLACEHOLDER — replace after running nixos-generate-config on actual hardware
{ config, lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "thunderbolt" ];
  boot.kernelModules = [ "kvm-amd" ];

  # PLACEHOLDER — replace with output from nixos-generate-config
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@" "compress=zstd" "noatime" ]; };
  fileSystems."/home" = { device = "/dev/disk/by-label/nixos"; fsType = "btrfs"; options = [ "subvol=@home" "compress=zstd" "noatime" ]; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/BOOT"; fsType = "vfat"; };
  swapDevices = [];

  networking.useDHCP = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
