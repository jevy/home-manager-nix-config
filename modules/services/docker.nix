# Docker and libvirtd virtualization
{ ... }:
{
  flake.modules.nixos.docker =
    { lib, pkgs, ... }:
    {
      virtualisation.docker = {
        enable = true;
        storageDriver = lib.mkDefault "zfs";
      };

      # Libvirtd for VMs
      # From: https://www.reddit.com/r/VFIO/comments/p4kmxr/tips_for_single_gpu_passthrough_on_nixos/
      virtualisation.libvirtd = {
        enable = true;
        qemu.runAsRoot = true;
        qemu.vhostUserPackages = [ pkgs.virtiofsd ];
      };

      programs.virt-manager.enable = true;
      # Note: Windows 11 guests can't auto-resize the display with QXL video
      # (QXL DOD driver on Win10/11 ignores ChangeDisplaySettings from spice-vdagent).
      # To enable auto-resize, switch the VM's video model from `qxl` to `virtio`
      # and install the vioGPU driver inside Windows from the virtio-win ISO
      # (D:\vioGPU\w11\amd64\vioGpuDod.inf). Otherwise use View → Scale Display → Always.

      environment.systemPackages = [ pkgs.virtiofsd ];

      # Override virt-secret-init-encryption: it hardcodes /usr/bin/sh (broken on NixOS)
      # and we don't use libvirt's secret encryption feature.
      # Use a no-op script instead of masking, since masking blocks libvirtd.socket.
      systemd.services.virt-secret-init-encryption.serviceConfig.ExecStart = lib.mkForce "${lib.getExe' pkgs.coreutils "true"}";
    };
}
