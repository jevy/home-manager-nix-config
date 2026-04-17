# PLACEHOLDER — Generate on the OptiPlex 5070 with:
#   nixos-generate-config --root / --dir /tmp/nixos-config
# Then copy the hardware-configuration.nix contents here.
{ config, lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # TODO: Replace with actual DeskMini hardware scan output
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Filesystems managed by disko — do not define here

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
