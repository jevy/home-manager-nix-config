# Nightly restic backup of ~/Documents to the TrueNAS `backups` dataset.
#
#   ~/Documents ──restic──▶ 192.168.6.157:/mnt/orignal-disks/backups
#                             (NFS automount at /mnt/truenas-backups)
#                             └─ lenovo-p14s/restic/   ← the repo
#
# Encrypted, which was a deliberate trade: the passphrase lives in 1Password
# ("Restic backup repo - lenovo-p14s Documents", Private vault) and in sops as
# `restic_laptop_password` for unattended runs. Read the warning at the bottom.
#
# TrueNAS runs NOTHING for this. Restic treats the NFS-mounted directory as a
# plain local repo; TrueNAS only stores and scrubs bytes. All repo management
# (forget, prune, check) runs from this laptop on the same timer, via the
# upstream module's pruneOpts/checkOpts rather than anything hand-rolled.
#
# Recovery needs exactly three things, and none of them is this file: the repo
# directory, the passphrase, and a restic binary.
#
#   restic -r /mnt/orignal-disks/backups/lenovo-p14s/restic snapshots
#   restic -r ... restore <snapshot-id> --target /somewhere
#   restic -r ... mount /mnt/x          # browse it like a filesystem
#
# Runs as the user (home-manager), not root, for two reasons: the source tree is
# user-owned, and the sops secret is a home-manager secret that only exists once
# the user's systemd session has activated. A root service could race that.
#
# WARNING, the cost of encryption: there is no escrow and no backdoor. Lose both
# 1Password and this laptop and the backup is cryptographically unrecoverable.
# Keep a paper copy of the passphrase.
#
# ALSO: encryption does not protect against deletion. A bad `restic forget`, or
# ransomware reaching the NFS mount, can destroy the repo. A ZFS periodic
# snapshot task on orignal-disks/backups is the guard for that, configured in
# the TrueNAS UI. As of 2026-09-11 that dataset had no snapshot task.
#
# History: this replaces a `services.restic` block in modules/services/backup.nix
# that declared a repo but no `paths`. The upstream module gates on
# `doBackup = dynamicFilesFrom != null || paths != []`, so with no paths it
# emitted a unit with no ExecStart, systemd refused it every boot, and the timer
# sat inactive. It had also pointed at a cluster-internal rest-server host that
# does not resolve from the laptop.
{ ... }:
let
  truenasHost = "192.168.6.157";
  nfsExport = "/mnt/orignal-disks/backups";
  mountPoint = "/mnt/truenas-backups";

  # Where this host's repo lives inside the share.
  repoPath = "${mountPoint}/lenovo-p14s/restic";
in
{
  # System half: the NFS mount the repo lives on.
  flake.modules.nixos.laptopBackup = {
    # On-demand mount. `noauto` + automount means an off-network or suspended
    # laptop neither blocks boot nor hangs on a dead server, and the idle
    # timeout unmounts it again so the share is not permanently writable.
    fileSystems.${mountPoint} = {
      device = "${truenasHost}:${nfsExport}";
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

  # User half: the backup itself.
  flake.modules.homeManager.laptopBackup =
    { config, pkgs, ... }:
    {
      # The upstream module gates its whole config block on this; without it the
      # backups attrset below is parsed and then silently produces no units.
      services.restic.enable = true;

      services.restic.backups.truenas-documents = {
        repository = repoPath;
        passwordFile = config.sops.secrets.restic_laptop_password.path;

        paths = [ "${config.home.homeDirectory}/Documents" ];

        exclude = [
          "*.part"
          "*.crdownload"
          ".Trash-*"
          ".DS_Store"
          ".stfolder"
          ".stversions"
        ];

        # Creates the repo on first run. Safe to leave true: restic refuses to
        # re-init over an existing repo.
        initialize = true;

        # Touching the path triggers the automount, then bail out rather than
        # writing a fresh repo onto the laptop's own disk if the mount failed.
        backupPrepareCommand = ''
          mkdir -p ${repoPath}
          if ! ${pkgs.util-linux}/bin/mountpoint -q ${mountPoint}; then
            echo "${mountPoint} is not mounted; refusing to touch the local disk" >&2
            exit 1
          fi
        '';

        # Retention. Runs after the backup, so "keep 7 daily" includes today's.
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 5"
        ];

        # Verify repo structure on each run. Cheap without --read-data, which
        # would re-download everything; ZFS scrubs cover bit rot on the TrueNAS
        # side, so structural checks are the useful half here.
        checkOpts = [ "--with-cache" ];

        timerConfig = {
          OnCalendar = "03:30";
          # A laptop is asleep at 03:30 more often than not; catch up on wake.
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };
    };
}
