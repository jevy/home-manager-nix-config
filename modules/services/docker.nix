# Docker and libvirtd virtualization
{ ... }:
{
  flake.modules.nixos.docker =
    { ... }:
    {
      virtualisation.docker = {
        enable = true;
        storageDriver = "zfs";
      };

      # Libvirtd for VMs
      # From: https://www.reddit.com/r/VFIO/comments/p4kmxr/tips_for_single_gpu_passthrough_on_nixos/
      virtualisation.libvirtd = {
        enable = true;
        qemu.runAsRoot = true;
      };
    };
}
