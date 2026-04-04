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

      environment.systemPackages = [ pkgs.virtiofsd ];

      # Override virt-secret-init-encryption: it hardcodes /usr/bin/sh (broken on NixOS)
      # and we don't use libvirt's secret encryption feature.
      # Use a no-op script instead of masking, since masking blocks libvirtd.socket.
      systemd.services.virt-secret-init-encryption.serviceConfig.ExecStart = lib.mkForce "${lib.getExe' pkgs.coreutils "true"}";
    };
}
