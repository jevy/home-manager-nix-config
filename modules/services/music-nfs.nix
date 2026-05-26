# NFS automount for the navidrome/beets/ytdl-sub music library.
# Backed by the democratic-csi-provisioned PVC on TrueNAS — see
# apps/navidrome/pvc-music.yaml in home-infrastructure-flux.
{ ... }:
{
  flake.modules.nixos.musicNfs =
    { ... }:
    {
      fileSystems."/mnt/music" = {
        device = "192.168.6.157:/mnt/orignal-disks/kubernetes/volumes/pvc-884e7539-463a-48e9-a0eb-08491aa52183";
        fsType = "nfs";
        options = [
          "nfsvers=4.1"
          "noatime"
          "soft"
          "timeo=50"
          "retrans=2"
          "x-systemd.automount"
          "x-systemd.idle-timeout=600"
          "x-systemd.mount-timeout=10s"
          "noauto"
        ];
      };
    };
}
