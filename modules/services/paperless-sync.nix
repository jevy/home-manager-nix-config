# Ship new documents from ~/Documents into the paperless-ngx consume share.
#
#   ~/Documents ──rsync──▶ 192.168.6.157:/mnt/orignal-disks/paperless-consume
#                            (NFS automount at /mnt/truenas-paperless)
#                            └─ consumed, OCR'd and DELETED by paperless
#
# ~/Documents is the system of record. Paperless holds a DERIVED copy and this
# sync is one-way, never `--delete`: paperless empties the consume directory as
# it ingests, and a mirroring rsync would read that as "the source deleted these"
# and propagate it. Nothing here can lose a document.
#
# Ordering: modules/services/laptop-backup.nix runs restic at 03:30, this runs at
# 04:30. Backup first, always -- each night's restic snapshot predates that
# night's sync.
#
# Deliberately NOT sent: ~/Documents is 22G/59k files, but only ~7.7k of those are
# documents. The rest is a node_modules tree, Arduino sketches, desktop
# backgrounds and an AICamera dump. The find filter below is the whole scoping
# mechanism -- there is no directory allowlist to maintain, only a type filter
# plus two explicit secret-bearing directories and a denylist for build
# detritus (node_modules, dot-directories) that the type filter cannot scope
# out on its own.
#
# Why the stamp file: paperless DELETES each file from consume/ once it has
# ingested it, so the destination is empty by design. A plain `rsync ~/Documents/`
# would therefore see every file as missing and re-ship all 4.6G every single
# night. The stamp makes each run incremental -- first run ships everything,
# later runs ship only what changed.
#
# Belt and braces: the cluster sets PAPERLESS_CONSUMER_DELETE_DUPLICATES=true, so
# even if the stamp is lost or a clock skews and a file is re-shipped, paperless
# rejects it by SHA-256 rather than creating a second document. The stamp is a
# bandwidth optimisation; the dedupe is the correctness guarantee.
#
# Tags come from the directory structure: the cluster sets CONSUMER_RECURSIVE +
# CONSUMER_SUBDIRS_AS_TAGS, so the consume-relative path of each file becomes its
# tags. That is why this uses `--files-from` (which preserves relative paths)
# rather than flattening everything into one directory.
#
# Future: nixos.scanner already configures the ScanSnap S1300. Pointing its
# scan-to-folder output at ~/Documents/Scans would make scanned paper flow through
# this same path with no changes here.
{ ... }:
let
  truenasHost = "192.168.6.157";
  nfsExport = "/mnt/orignal-disks/paperless-consume";
  mountPoint = "/mnt/truenas-paperless";
in
{
  # System half: the NFS mount, mirroring nixos.laptopBackup's.
  flake.modules.nixos.paperlessSync = {
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

  # User half: the sync itself. Runs as the user because the source tree is
  # user-owned; the NFS share maps all client users to root on the NAS, so the
  # writes land as root there regardless of who runs them.
  flake.modules.homeManager.paperlessSync =
    { config, pkgs, ... }:
    let
      documentsDir = "${config.home.homeDirectory}/Documents";
      stateDir = "${config.xdg.stateHome}/paperless-sync";
      stamp = "${stateDir}/last-sync";

      syncScript = pkgs.writeShellApplication {
        name = "paperless-sync";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          rsync
          util-linux
        ];
        text = ''
          set -euo pipefail

          DOCS=${documentsDir}
          DEST=${mountPoint}
          STAMP=${stamp}

          mkdir -p ${stateDir}

          # Wait for the automount, then bail out rather than writing into the
          # root-owned autofs stub directory on the local disk if it never came up.
          #
          # `ls` inside the directory is the trigger: a bare stat of an autofs
          # mountpoint does not always fire it, a readdir within it does. Polling
          # rather than trying once is the point -- see the Persistent=true note
          # on the timer below.
          tries=0
          until mountpoint -q "$DEST"; do
            ls "$DEST" >/dev/null 2>&1 || true
            tries=$((tries + 1))
            if [ "$tries" -ge 24 ]; then
              echo "$DEST did not mount after ~2min; refusing to write to the local disk" >&2
              exit 1
            fi
            sleep 5
          done

          # Mark "now" BEFORE listing. Committed to $STAMP only if rsync succeeds
          # (set -e aborts first otherwise), so a failed run re-ships next time
          # rather than silently skipping files. Files modified DURING the rsync
          # are newer than this reference and so are caught on the following run.
          ref=$(mktemp)
          trap 'rm -f "$ref"' EXIT
          touch "$ref"

          # The scoping filter. Type-based, so there is no directory allowlist to
          # keep in step with however ~/Documents is reorganised.
          #
          # 1Password/ needs no exclusion by content -- it holds zero .pdf and
          # zero .txt -- but it is listed anyway so that stays true if its
          # contents ever change.
          #
          # .md and .html are absent on purpose: paperless rejects unsupported
          # extensions outright, and ~/Documents holds ~1.3k of each that would
          # only generate failed-consume noise.
          #
          # node_modules and dot-directories are excluded because the TYPE filter
          # alone does not scope them out: a node_modules tree is full of
          # LICENSE.txt, usage.txt and test fixtures, and .devenv/ holds
          # imports.txt. 50 such files were reaching paperless, where
          # CONSUMER_SUBDIRS_AS_TAGS turned their paths into ~35 junk tags
          # (node_modules, cliui, yargs-parser, tough-cookie, grunt-zip, ...)
          # permanently polluting the tag vocabulary.
          #
          # The patterns match at ANY depth, unlike the three above them: the
          # real tree is ./Presentations/PTA_Auctria/node_modules/..., so a
          # './node_modules/*' rule anchored at the root would miss every one.
          # '*/.*/*' covers every hidden directory in one rule rather than
          # naming .devenv, .git, .venv and whatever comes next; ~/Documents is
          # a human document tree, so a dot-directory in it is always tooling.
          #
          # Paths MUST be relative to $DOCS. rsync's --files-from resolves every
          # entry against the source root, so feeding it absolute paths makes it
          # prepend the root to a path that already has it:
          #   /home/jevin/Documents/home/jevin/Documents/resume/resume.pdf
          #                                  ^ doubled
          # and every single file fails link_stat with ENOENT (rsync exit 23).
          # Hence `cd` plus `find .` rather than `find "$DOCS"`.
          cd "$DOCS"
          find_args=(
            . -type f
            \( -iname '*.pdf' -o -iname '*.txt' \)
            -not -path './1Password/*'
            -not -path './Accounts:Passwords/*'
            -not -path './JevinsSecrets/*'
            -not -path '*/node_modules/*'
            -not -path '*/.*/*'
          )
          if [ -e "$STAMP" ]; then
            echo "Incremental: files changed since $(date -r "$STAMP" '+%Y-%m-%d %H:%M')"
            find_args+=( -newer "$STAMP" )
          else
            echo "First run: shipping the full document set"
          fi

          # -print0 / --from0 because these paths contain spaces and colons
          # ("132 Marrissa", "Accounts:Passwords").
          #
          # --files-from preserves each file's path relative to $DOCS, which is
          # what CONSUMER_SUBDIRS_AS_TAGS turns into tags on the cluster side.
          #
          # No --delete, ever: see the header.
          #
          # Ownership and permissions are dropped rather than preserved: the NFS
          # share maps every client user to root, so attempting to set them is
          # both meaningless and a source of spurious errors.
          count=$(find "''${find_args[@]}" -print | wc -l)
          if [ "$count" -eq 0 ]; then
            echo "Nothing new to ship."
          else
            echo "Shipping $count file(s) to $DEST"
            find "''${find_args[@]}" -print0 \
              | rsync -rlt --from0 --files-from=- \
                  --no-owner --no-group --no-perms \
                  --info=stats1 \
                  "$DOCS/" "$DEST/"
          fi

          # Commit the watermark only now that the transfer actually succeeded.
          mv "$ref" "$STAMP"
          trap - EXIT
          echo "Sync complete."
        '';
      };
    in
    {
      systemd.user.services.paperless-sync = {
        Unit = {
          Description = "Ship new ~/Documents files into the paperless consume share";
          # Do NOT let home-manager restart this on a config change.
          #
          # sd-switch restarts any unit whose definition changed, and
          # `systemctl start` on a Type=oneshot BLOCKS until the unit finishes.
          # This one runs for minutes to hours, so a rebuild that happens while
          # it is mid-run leaves home-manager-jevin.service waiting on it, and
          # `rebuildhm` hangs at "restarting sysinit-reactivation.target" with no
          # indication why. Observed 2026-09-23 during the first mail backfill.
          #
          # `keep-old` is correct rather than merely expedient: this is timer-driven,
          # so there is nothing to restart into -- the next firing picks up the
          # new definition on its own.
          "X-SwitchMethod" = "keep-old";
          # Retry, because Persistent=true fires the catch-up run in the same
          # second systemd finishes resuming from suspend -- before Wi-Fi is
          # associated and long before NFS is reachable. This is the exact
          # failure that cost laptop-backup.nix nine consecutive nights; see its
          # comment. on-failure is legal on Type=oneshot -- only always and
          # on-success are rejected.
          StartLimitIntervalSec = 3600;
          StartLimitBurst = 6;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${syncScript}/bin/paperless-sync";
          Restart = "on-failure";
          RestartSec = 300;
        };
      };

      systemd.user.timers.paperless-sync = {
        Unit.Description = "Nightly paperless document sync";
        Timer = {
          # An hour after the 03:30 restic run in laptop-backup.nix.
          OnCalendar = "04:30";
          # A laptop is asleep at 04:30 more often than not; catch up on wake.
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
