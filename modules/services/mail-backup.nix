# Nightly restic backup of the lieer/notmuch Gmail mirror to the TrueNAS
# `backups` dataset.
#
#   ~/Maildir ──restic──▶ 192.168.6.157:/mnt/orignal-disks/backups
#                           (NFS automount at /mnt/truenas-backups)
#                           └─ lenovo-p14s/mail/restic/   ← the repo
#
# The NFS mount itself is declared once, by nixos.laptopBackup in
# modules/services/laptop-backup.nix. This module is the user half only; it
# would be a `fileSystems` conflict to redeclare the mount here.
#
# Measured 2026-09-22, restic --dry-run:
#
#   545,439 files, 45.749 GiB scanned in 9.3s
#   43.314 GiB added, 28.041 GiB stored after compression
#
# ---------------------------------------------------------------------------
# WHY THE XAPIAN INDEX IS EXCLUDED, AND WHY THAT NEEDS A TAG DUMP
# ---------------------------------------------------------------------------
#
# ~/Maildir/.notmuch/xapian is 9.1 GiB of derived index, and lieer-quickjack
# rewrites it every five minutes (OnCalendar=*:0/5, then `notmuch new` as
# ExecStartPost). Copying a live Xapian database mid-write gives you a file set
# that may not open, so backing it up is both expensive and unreliable.
#
# But it cannot simply be dropped, because this account has
# `maildir.synchronize_flags=false`: tags are NOT encoded into maildir
# filenames, so Xapian is the only place they exist. Nor is a full `gmi pull`
# a complete fallback -- .gmailieer.json sets
#
#   "ignore_remote_labels": ["important"]
#
# so lieer will not re-derive the `important` tag from Gmail, and that tag is on
# 253,019 messages here. `flagged` (675) and `thoughtful` (30) are in the same
# position.
#
# So: exclude the index, and capture the tags as a flat text dump instead.
# 10.8s, 16 MiB gzipped, 542,812 lines of `+tag +tag -- id:<message-id>`.
# `notmuch dump` opens the database read-only and Xapian permits one writer
# alongside many readers, so this is safe to run against the live 5-minute sync.
#
# The dump lands OUTSIDE ~/Maildir on purpose. Inside it, `notmuch new` would
# try to index the dump as a message every five minutes.
#
# ---------------------------------------------------------------------------
# RESTORE
# ---------------------------------------------------------------------------
#
#   restic -r /mnt/truenas-backups/lenovo-p14s/mail/restic snapshots
#   restic -r ... restore <snapshot-id> --target /
#   notmuch new                    # rebuild the index -- SLOW, hours for 542k
#   zcat ~/.local/state/notmuch-backup/tags.gz | notmuch restore --input=-
#
# `notmuch restore` matches on Message-ID, so it works even though the rebuilt
# index has entirely different internal document ids. The index rebuild is the
# slow half of a restore; that is the deliberate trade for not shipping 9.1 GiB
# of unreliable Xapian every night.
#
# .credentials.gmailieer.json (the OAuth token) and .state.gmailieer.json (the
# last Gmail historyId) are both in the backup set. Together they let lieer
# resume incrementally instead of re-pulling 542k messages. The credentials file
# has no other copy -- it is not in sops -- though `gmi auth` re-auths in a
# browser in about a minute if it is ever lost.
#
# ---------------------------------------------------------------------------
# A SEPARATE REPO, NOT A SECOND PATH ON truenas-documents
# ---------------------------------------------------------------------------
#
#   1. Failure isolation: a 545k-file mail scan failing should not stop the
#      Documents backup, and vice versa.
#   2. Lock contention: `forget --prune` takes an exclusive repo lock. Two jobs
#      against one repo that overlap -- more likely now that both retry on
#      failure -- would start failing each other.
#   3. Different profiles: Documents is small and churns; mail is enormous and
#      near-immutable. They want different schedules and different check
#      frequencies.
#
# The passphrase is deliberately the SAME sops secret as the Documents repo, so
# there is still only one thing to keep in 1Password. Recovery needs the repo
# directory, that passphrase, and a restic binary.
{ ... }:
let
  mountPoint = "/mnt/truenas-backups";
  repoPath = "${mountPoint}/lenovo-p14s/mail/restic";
in
{
  flake.modules.homeManager.mailBackup =
    { config, pkgs, ... }:
    let
      maildir = "${config.home.homeDirectory}/Maildir";
      # Regenerable state, so ~/.local/state rather than anywhere backed up for
      # its own sake. It is in `paths` below because the dump IS the point.
      dumpDir = "${config.home.homeDirectory}/.local/state/notmuch-backup";
      dumpFile = "${dumpDir}/tags.gz";
      # Not ~/.notmuch-config: this account's config is the XDG one, a symlink
      # into the store. Without NOTMUCH_CONFIG pointing here, notmuch does not
      # find the database at all. The lieer unit sets the same variable.
      notmuchConfig = "${config.xdg.configHome}/notmuch/default/config";
    in
    {
      services.restic.enable = true;

      services.restic.backups.truenas-mail = {
        repository = repoPath;
        passwordFile = config.sops.secrets.restic_laptop_password.path;

        paths = [
          maildir
          dumpDir
        ];

        exclude = [
          # 9.1 GiB of derived index, rewritten every 5 minutes. See the header.
          "${maildir}/.notmuch"
          # In-flight maildir writes.
          "${maildir}/quickjack/mail/tmp"
          # lieer's interrupted-pull scratch file: 10 MiB, stale since April.
          ".resume-pull.gmailieer.json.bak"
          # lieer's sync lock.
          ".lock"
          "*.part"
        ];

        initialize = true;

        # Wait for the automount, then dump the tags, then let restic run. Same
        # polling approach as laptop-backup.nix and for the same reason: the
        # Persistent=true catch-up fires the instant the laptop resumes, before
        # the network is up.
        #
        # The dump runs AFTER the mount is confirmed -- no point spending 11s on
        # it if there is nowhere to put the result -- and the wrapper script runs
        # under `set -o pipefail`, so a failed dump fails the unit and trips the
        # retry below rather than quietly backing up a stale tags.gz.
        backupPrepareCommand = ''
          tries=0
          until ${pkgs.util-linux}/bin/mountpoint -q ${mountPoint}; do
            ls ${mountPoint} >/dev/null 2>&1 || true
            tries=$((tries + 1))
            if [ "$tries" -ge 24 ]; then
              echo "${mountPoint} did not mount after ~2min; refusing to touch the local disk" >&2
              exit 1
            fi
            ${pkgs.coreutils}/bin/sleep 5
          done
          mkdir -p ${repoPath} ${dumpDir}

          NOTMUCH_CONFIG=${notmuchConfig} \
            ${pkgs.notmuch}/bin/notmuch dump \
            | ${pkgs.gzip}/bin/gzip -c > ${dumpFile}
        '';

        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 5"
        ];

        # The upstream module runs `restic check` inside the same unit on EVERY
        # run, and a structural check of a 28 GiB repo nightly is a lot of Wi-Fi
        # for little return on near-immutable data. The weekly restic-check-mail
        # units below do it instead.
        #
        # runCheck must be set explicitly. Emptying checkOpts is NOT enough --
        # it defaults to `checkOpts != [] || pruneOpts != []`, so a non-empty
        # pruneOpts (above) turns the check back on, and with no checkOpts it
        # then runs a bare `restic check` WITHOUT --with-cache, which is worse
        # than what it replaced. Verified against the generated unit.
        runCheck = false;
        checkOpts = [ ];

        timerConfig = {
          # An hour after truenas-documents (03:30) so the two never contend for
          # the NFS mount or the laptop's uplink.
          OnCalendar = "04:30";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };

      # Same retry rationale as laptop-backup.nix: Persistent=true fires the
      # catch-up run in the same second systemd finishes resuming from suspend,
      # before Wi-Fi is associated. Capped at 6 attempts per hour.
      #
      # It matters more here. The first run moves 28 GiB, which is ~25 min over
      # the measured 19.4 MB/s Wi-Fi link and does not fit between two suspends.
      # restic is safe under interruption -- finished pack files persist and a
      # re-run continues -- so repeated attempts converge. Run the first one on
      # ethernet anyway.
      systemd.user.services."restic-backups-truenas-mail" = {
        Unit = {
          StartLimitIntervalSec = 3600;
          StartLimitBurst = 6;
        };
        Service = {
          Restart = "on-failure";
          RestartSec = 300;
        };
      };

      # Weekly structural check, split out of the backup unit (see checkOpts).
      # --with-cache, not --read-data: re-reading 28 GiB over NFS every week
      # would be pointless when TrueNAS scrubs orignal-disks for bit rot. This
      # checks that the repo's own structure is intact.
      systemd.user.services."restic-check-mail" = {
        Unit = {
          Description = "Weekly restic structural check of the mail repo";
          StartLimitIntervalSec = 3600;
          StartLimitBurst = 4;
        };
        Service = {
          Type = "oneshot";
          Environment = [
            "RESTIC_REPOSITORY=${repoPath}"
            "RESTIC_PASSWORD_FILE=${config.sops.secrets.restic_laptop_password.path}"
          ];
          ExecStartPre = pkgs.writeShellScript "restic-check-mail-wait-mount" ''
            tries=0
            until ${pkgs.util-linux}/bin/mountpoint -q ${mountPoint}; do
              ls ${mountPoint} >/dev/null 2>&1 || true
              tries=$((tries + 1))
              if [ "$tries" -ge 24 ]; then
                echo "${mountPoint} did not mount after ~2min; skipping check" >&2
                exit 1
              fi
              ${pkgs.coreutils}/bin/sleep 5
            done
          '';
          ExecStart = "${pkgs.restic}/bin/restic check --with-cache";
          Restart = "on-failure";
          RestartSec = 900;
        };
      };

      systemd.user.timers."restic-check-mail" = {
        Unit.Description = "Weekly restic structural check of the mail repo";
        Timer = {
          # Sunday, well clear of the 04:30 backup.
          OnCalendar = "Sun 06:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
