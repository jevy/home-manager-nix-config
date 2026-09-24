# Lenovo ThinkPad P14s Gen 6 AMD host definition
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  configurations.nixos."lenovo-p14s".module =
    { pkgs, lib, ... }:
    {
      imports = [
        # Hardware
        ../../../nixos/lenovo-p14s-hardware-configuration.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p14s-amd-gen6
        nixos.lenovoP14sHardware

        # Race fingerprint + password in polkit's PAM stack
        nixos.pamFprintRace

        # Shared Linux desktop base
        nixos.linuxDesktopBase

        # Auto-switch power profile (performance/balanced/power-saver)
        nixos.powerProfileSwitcher

        # NFS automount of navidrome music library (TrueNAS via democratic-csi PVC)
        nixos.musicNfs

        # SANE + ScanSnap S1300 (epjitsu backend)
        nixos.scanner

        # Nightly restic backup of ~/Documents to the TrueNAS backups dataset
        # (NFS mount here; the backup itself is homeManager.laptopBackup below)
        nixos.laptopBackup

        # NFS automount of the paperless-ngx consume share (the sync itself is
        # homeManager.paperlessSync below)
        nixos.paperlessSync
      ];

      networking.hostName = "lenovo-p14s";

      # LUKS
      boot.initrd.luks.devices."cryptroot".device =
        "/dev/disk/by-uuid/93f39771-d83e-4b78-baa2-13c6f7f921f1";

      # Btrfs, not ZFS (NFS for the music share — see nixos.musicNfs)
      virtualisation.docker.storageDriver = "btrfs";
      boot.supportedFilesystems = lib.mkForce [
        "btrfs"
        "nfs"
      ];

      # === TEMPORARY: disable hy3 plugin to isolate boot issue ===

      home-manager.users.jevin = {
        imports = [
          # Nightly restic backup of ~/Documents to TrueNAS (repo lives on the
          # NFS mount declared by nixos.laptopBackup above)
          homeManager.laptopBackup

          # Nightly restic backup of the lieer/notmuch Gmail mirror, to its own
          # repo on that same NFS mount (no nixos.* half -- the mount is
          # already declared by nixos.laptopBackup)
          homeManager.mailBackup

          # OnFailure notifier both backup jobs above hang their failures on
          homeManager.backupNotify

          # Nightly one-way sync of new ~/Documents PDFs/text into the
          # paperless-ngx consume share (mount from nixos.paperlessSync above).
          # Runs at 04:30, an hour after the restic backup above.
          homeManager.paperlessSync

          # Nightly push of PDF attachments from the notmuch mail mirror into
          # paperless-ngx via its REST API (no NFS mount involved). Runs at
          # 05:30, after the document sync. Also provides the
          # paperless-mail-unmatched and paperless-mail-repair commands.
          homeManager.paperlessMailSync

          # MeshCore LoRa mesh clients: the meshy GUI (built from pkgs/) plus
          # the official meshcore-cli. Here rather than in linux-desktop-base
          # because the companion radio lives on this laptop.
          homeManager.meshcore

          # Local LLM proxy on 127.0.0.1:9292 (Vulkan, Radeon 860M). Host-level
          # rather than in linux-desktop-base because it is specific to this
          # machine's iGPU sizing -- see the module header for the 25.38 GB pool
          # the model quants are chosen against.
          homeManager.llamaSwapLinux
        ];

        # P14s OLED monitor: 2880x1800 @ 120Hz, scale 1.5 (→ 1920x1200 logical)
        wayland.windowManager.hyprland.settings.monitor = lib.mkForce "eDP-1,2880x1800@120,0x0,1.5";
        # Override the defaults from modules/desktop/hyprland.nix so the
        # monitor-attach/detach/scale-toggle scripts use the right values.
        # Hyprland applies env entries in order; later entries win.
        wayland.windowManager.hyprland.settings.env = [
          "HYPR_LAPTOP_MODE,2880x1800@120"
          "HYPR_LAPTOP_SCALE,1.5"
        ];

        # AMD GPU session variables
        home.sessionVariables = {
          LIBVA_DRIVER_NAME = "radeonsi";
          __GLX_VENDOR_LIBRARY_NAME = "mesa";
        };
      };
    };
}
