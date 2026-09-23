# Push PDF attachments from the lieer/notmuch Gmail mirror into paperless-ngx,
# with the email's own metadata attached.
#
#   notmuch (~/Maildir) ──HTTPS──▶ paperless.jevy.org /api/documents/
#
# Deliberately NOT the consume directory that modules/services/paperless-sync.nix
# uses. The REST API accepts title/created/correspondent/tags/custom_fields on
# upload, so the email's real metadata survives instead of being encoded into a
# filename and re-parsed. It also sidesteps filename collisions entirely — 93
# separate Intuit mails all attach a file called `invoice.pdf`.
#
# WHY AN ALLOWLIST: 12,213 of the 542,614 indexed messages carry a PDF, but the
# overwhelming majority are recurring SaaS invoices and marketing. Filtering by
# sender domain keeps ~1,155 documents that are actually worth searching: school
# board, psychology, dentistry, city, insurance, accountants, receipts, travel.
#
# TWO PHASES, NOT ONE: the upload endpoint returns a task UUID rather than a
# document id, so the email's own body cannot be attached in the same call. The
# script therefore uploads fire-and-forget, then runs a context pass that finds
# mail documents by their `Email Message-ID` custom field and PATCHes the body
# in. Waiting for each OCR instead -- which is what it used to do -- serialised
# the whole nightly run behind the consumer and stalled it for 20 minutes.
# `paperless-mail-repair` is that same context pass on its own, still the right
# tool after a bulk reprocess wipes `content`.
#
# HOW IT KNOWS WHAT IS NEW: notmuch's `lastmod` database revision, not dates and
# not file mtimes. The Date: header is sender-controlled, so backdated mail would
# be missed forever; lieer rewrites maildir files on every label change, so mtime
# churns constantly on decade-old mail. lastmod answers the actual question —
# "what has the database learned since revision N". The database UUID is stored
# alongside it because a `notmuch new --full-scan` rebuild restarts revisions from
# zero, which would otherwise silently sync nothing ever again.
#
# ON DEAD DOMAINS: several entries below have not sent anything in years (Logan
# Katz last wrote in 2013). They stay because a dead domain costs nothing — it
# matches no new mail — while the historical tax, insurance and incorporation
# records it holds are exactly what an archive is for. The "ignore anything
# silent for a year" rule applies to ADDING domains, which is what
# `paperless-mail-unmatched` is for.
{ ... }:
let
  paperlessUrl = "https://paperless.jevy.org";

  # domain -> correspondent name. Several domains deliberately map onto one
  # correspondent: on.aibn.com is the same psychologists as deltapsychology.ca on
  # their older domain, and Home Depot and Porter each send from two.
  correspondents = {
    "ocdsb.ca" = "OCDSB";
    "ocsb.ca" = "OCSB";
    "schoolconnectsweb.com" = "OCDSB";
    "deltapsychology.ca" = "Delta Psychology";
    "on.aibn.com" = "Delta Psychology";
    "owlpractice.ca" = "Owl Practice";
    "janeapp.com" = "Jane";
    "mcallisterdentistry.ca" = "McAllister Dentistry";
    "navigators.ca" = "Navigators Insurance";
    "ottawa.ca" = "City of Ottawa";
    "canada.ca" = "Corporations Canada";

    "notification.intuit.com" = "QuickBooks";
    "homedepot.com" = "Home Depot";
    "order.homedepot.com" = "Home Depot";
    "xero.com" = "Xero";
    "post.xero.com" = "Xero";
    "stripe.com" = "Stripe";
    "logankatz.com" = "Logan Katz";
    "kirkcpa.ca" = "Kirk CPA";
    "ignitionapp.com" = "Ignition";
    "dubecuttini.com" = "Dube Cuttini";
    "ikea.com" = "IKEA";
    "richelieu.com" = "Richelieu";

    # Legal and property. Verified high-signal before adding: every sampled
    # subject was a filing, invoice, lease or case letter -- no marketing, unlike
    # Richelieu/IKEA which mix promotional flyers in with receipts.
    "nelliganlaw.ca" = "Nelligan O'Brien Payne";
    "lmslawyers.com" = "LMS Lawyers";
    "royallepage.ca" = "Royal LePage";

    "aircanada.ca" = "Air Canada";
    "viarail.ca" = "Via Rail";
    "flyporter.com" = "Porter Airlines";
    "notifications.flyporter.com" = "Porter Airlines";
  };

  # category -> the domains that belong to it. Becomes the second tag; every
  # document also gets the `Email` tag so mail-sourced documents can always be
  # told apart from the ~/Documents ones.
  categories = {
    "Health" = [
      "ocdsb.ca" "ocsb.ca" "schoolconnectsweb.com"
      "deltapsychology.ca" "on.aibn.com" "owlpractice.ca" "janeapp.com"
      "mcallisterdentistry.ca" "navigators.ca" "ottawa.ca" "canada.ca"
    ];
    "Finance" = [
      "notification.intuit.com" "homedepot.com" "order.homedepot.com"
      "xero.com" "post.xero.com" "stripe.com" "logankatz.com" "kirkcpa.ca"
      "ignitionapp.com" "dubecuttini.com" "ikea.com" "richelieu.com"
    ];
    # Royal LePage sits here rather than under Finance: the documents are leases
    # and agreements for 1 Steel Street, not receipts.
    "Legal" = [ "nelliganlaw.ca" "lmslawyers.com" "royallepage.ca" ];
    "Travel" = [ "aircanada.ca" "viarail.ca" "flyporter.com" "notifications.flyporter.com" ];
  };
in
{
  flake.modules.homeManager.paperlessMailSync =
    { config, pkgs, ... }:
    let
      stateDir = "${config.xdg.stateHome}/paperless-mail-sync";

      configJson = pkgs.writeText "paperless-mail-sync.json" (builtins.toJSON {
        url = paperlessUrl;
        inherit correspondents categories;
      });

      pyEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);

      mkTool = name: script:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [ pyEnv pkgs.notmuch pkgs.coreutils ];
          text = ''
            # Without this, python buffers stdout whenever it is not a TTY --
            # which is always, under systemd. A multi-hour backfill would show
            # nothing in `journalctl -fu` until the very end, and a hang would be
            # indistinguishable from silence.
            export PYTHONUNBUFFERED=1
            export PAPERLESS_CONFIG=${configJson}
            export PAPERLESS_STATE=${stateDir}
            export PAPERLESS_TOKEN_FILE=${config.sops.secrets.paperless_api_token.path}
            mkdir -p ${stateDir}
            exec ${pyEnv}/bin/python3 ${script} "$@"
          '';
        };

      syncScript = ./paperless-mail-sync.py;

      sync = mkTool "paperless-mail-sync" "${syncScript} sync";
      unmatched = mkTool "paperless-mail-unmatched" "${syncScript} unmatched";
      repair = mkTool "paperless-mail-repair" "${syncScript} repair";
    in
    {
      home.packages = [ sync unmatched repair ];

      systemd.user.services.paperless-mail-sync = {
        Unit = {
          Description = "Push new mail PDF attachments into paperless-ngx";
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
          # Same post-suspend network race that cost laptop-backup.nix nine
          # consecutive nights; see its comment.
          StartLimitIntervalSec = 3600;
          StartLimitBurst = 6;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${sync}/bin/paperless-mail-sync";
          Restart = "on-failure";
          RestartSec = 300;
        };
      };

      systemd.user.timers.paperless-mail-sync = {
        Unit.Description = "Nightly paperless mail-attachment sync";
        Timer = {
          # An hour after paperless-sync (04:30), which is an hour after the
          # restic backup (03:30). Backup first, then documents, then mail.
          OnCalendar = "05:30";
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
