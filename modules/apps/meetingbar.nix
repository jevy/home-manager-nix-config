# MeetingBar — the next calendar event in the macOS menu bar.
#
# Shows the current/next event with a countdown in the status bar, lists today
# and tomorrow in the dropdown, fires a macOS notification before each meeting,
# and one-click joins Zoom/Meet/Teams and ~50 other services by scraping the
# join URL out of the event.
#
# IT CANNOT ACCEPT OR DECLINE INVITATIONS, and no amount of configuration will
# change that — it is an OS limit, not a missing feature. MeetingBar reads
# calendars through EventKit, which exposes an attendee's participation status
# read-only. Upstream closed exactly this request (leits/MeetingBar#249) with:
#
#   Unfortunately, I have to close this feature.
#   The status of the event cannot be changed programmatically.
#
# So every EventKit-based menu bar calendar — this, Itsycal, Calendr — is
# read-plus-join only. RSVP happens in Calendar.app or Gmail; MeetingBar's
# per-event "open in Calendar" action is the shortest path to it. Apps that do
# accept invitations inline (Fantastical, Notion Calendar, Morgen) talk to the
# Google/Microsoft APIs directly instead, and none of them are open source.
#
# WHY THE DARWIN LAYER RATHER THAN home.packages. Same reason as the GUI apps in
# environment.systemPackages in the mac-work host: nix-darwin builds an env with
# pathsToLink = [ "/Applications" ] and rsyncs it into /Applications/Nix Apps,
# a real copy in a location Spotlight indexes and TCC can hold a permission
# grant against. home-manager's user-scoped equivalent on this host would be
# targets.darwin.linkApps — its default, since that option is gated on
# `versionOlder home.stateVersion "25.11"` and mac-work is on "23.11" — which
# symlinks into /nix, and LaunchServices will not index those. home-manager
# 25.11 added targets.darwin.copyApps to fix precisely that (copies, works with
# Spotlight), but on a nix-darwin host the system layer is already the native
# path and needs no per-user opt-in.
#
# LSUIElement is true in its Info.plist: it is a menu bar agent with no Dock
# icon, so it never appears in ⌘Tab and there is nothing to "switch to". Launch
# it once from Spotlight or /Applications/Nix Apps, then turn on Launch at Login
# *inside its own preferences* — that writes an SMAppService registration, which
# is not declarable from Nix.
#
# NEEDS CALENDAR ACCESS, granted by hand on first launch
# (NSCalendarsFullAccessUsageDescription: "To get events to show on status bar")
# plus Notifications when it first tries to alert. Neither is grantable from
# Nix.
#
# EventKit reads only calendars macOS itself knows about, so a work Google or
# Exchange calendar has to be added under System Settings → Internet Accounts
# first. Without that MeetingBar authorises fine and then shows nothing, which
# reads as a broken app rather than an empty calendar list.
#
# NO PREFERENCES ARE DECLARED HERE. The domain is `leits.MeetingBar`, but its
# keys are not a documented interface, so they are left to the app's own UI. If
# that ever changes, write them with `defaults write` from an activation script
# and not via home.file — cfprefsd does not follow symlinks into the Nix store,
# so a symlinked plist reads back as "domain does not exist" and the app starts
# unconfigured. That was established the hard way in modules/desktop/alt-tab.nix;
# see its header before declaring any plist on this machine.
#
# ── THE SYNC WATCHDOG, AND WHY IT HAS TO EXIST HERE ──────────────────────────
#
# MeetingBar 5.0.0 stops syncing after sleep/wake and never recovers until it
# is relaunched. Diagnosed 2026-09-28 against the v5.0.0 source; the menu bar
# kept serving a 12-hour-old snapshot while every status field read healthy.
#
# The mechanism, in the app's own code:
#
#   Calendar/CalendarSync.swift
#     Merge3(defaultsChanged, Timer.every(180s), refreshSubject)
#       -> throttle(200ms)
#       -> flatMap(maxPublishers: .max(1))   <-- ONE fetch may be in flight
#       -> sink { publish calendars, events, ProviderHealth }
#
#   Providers/Google/GoogleCalendarEventStore.swift
#     cfg.waitsForConnectivity = true       <-- and NO timeoutIntervalFor*
#
# waitsForConnectivity without a resource timeout inherits the URLSession
# default of SEVEN DAYS. A request in flight when the machine sleeps neither
# fails nor returns; it parks. The Task awaiting it never completes, so the
# Future inside the flatMap never fulfils, so the single in-flight slot is
# never released — and the 3-minute timer, the NSWorkspace.didWake trigger and
# every settings change are silently dropped from then on. It is a deadlock,
# not a crash, which is why nothing is logged and nothing errors.
#
# The diagnostics cannot show it either. ProviderHealth.success(attempted:)
# sets lastSuccessfulRefresh and lastAttemptedRefresh from the SAME value, and
# providerHealth is assigned only in the sink — i.e. only when a cycle
# COMPLETES. An attempt that starts and hangs updates nothing, so "Last
# attempted refresh" means "when the last successful cycle began". During this
# failure the panel reports health ok, stale data no, last error none.
#
# WHY NOT PATCH IT. pkgs.meetingbar is not a source build:
#
#   src = fetchurl "https://github.com/leits/MeetingBar/releases/download/
#                   v5.0.0/MeetingBar.dmg"
#
# It is a prebuilt, signed .dmg. Patching CalendarSync.swift would mean
# building the Xcode app here and re-signing it, which also breaks the Google
# OAuth client the app ships. So the fix has to be external, and this is it.
#
# WHAT THE WATCHDOG WATCHES. Not the diagnostics panel — that field is in
# memory and lies during exactly this failure. It watches the app's URL cache
# instead: every completed poll writes a response through NSURLCache, so
# ~/Library/Caches/leits.MeetingBar/Cache.db-wal advances once per 3-minute
# cycle. VERIFIED 2026-09-28: launch at 12:45:51, cache write at 12:51:52 —
# two cycles, on the interval. A wedged app writes nothing at all.
#
# It is deliberately reluctant to act. A restart is user-visible, and a
# restart loop would be worse than the bug, so it fires only when the cache is
# 10+ minutes stale (three missed cycles), on two consecutive checks five
# minutes apart, with the network actually reachable, and at most once every
# 30 minutes. It never LAUNCHES MeetingBar — a not-running app is treated as
# deliberately quit and resets the strike count.
#
# REMOVE THIS once upstream lands a refresh timeout. The tell is
# CalendarSync.swift gaining a watchdog around the fetch, or the Google
# URLSessionConfiguration gaining timeoutIntervalForResource.
{ ... }:
{
  flake.modules.darwin.meetingbar =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.meetingbar ];
    };

  flake.modules.homeManager.meetingbarWatchdog =
    { config, pkgs, ... }:
    let
      staleSeconds = 600;
      strikesNeeded = 2;
      cooldownSeconds = 1800;
      checkInterval = 300;

      # macOS-specific tools are called by absolute path: writeShellApplication
      # prepends runtimeInputs to PATH, and a coreutils `stat` there would take
      # `-c %Y` rather than BSD `-f %m`.
      watchdog = pkgs.writeShellApplication {
        name = "meetingbar-watchdog";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          STALE=${toString staleSeconds}
          STRIKES_NEEDED=${toString strikesNeeded}
          COOLDOWN=${toString cooldownSeconds}

          PROC='MeetingBar.app/Contents/MacOS/MeetingBar'
          state_dir="$HOME/Library/Caches/meetingbar-watchdog"
          strikes_file="$state_dir/strikes"
          restart_file="$state_dir/last-restart"
          mkdir -p "$state_dir"

          log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }
          running() { pgrep -f "$PROC" >/dev/null 2>&1; }
          reset_strikes() { echo 0 > "$strikes_file"; }

          if ! running; then
            reset_strikes
            exit 0
          fi

          if ! curl -sf --max-time 5 -o /dev/null \
              https://connectivitycheck.gstatic.com/generate_204; then
            reset_strikes
            exit 0
          fi

          newest=0
          for f in \
            "$HOME/Library/Caches/leits.MeetingBar/Cache.db-wal" \
            "$HOME/Library/Caches/leits.MeetingBar/Cache.db" \
            "$HOME/Library/HTTPStorages/leits.MeetingBar/httpstorages.sqlite-wal"; do
            if [ -e "$f" ]; then
              m=$(/usr/bin/stat -f %m "$f")
              if [ "$m" -gt "$newest" ]; then newest=$m; fi
            fi
          done

          if [ "$newest" -eq 0 ]; then
            reset_strikes
            exit 0
          fi

          now=$(date +%s)
          age=$(( now - newest ))
          if [ "$age" -lt "$STALE" ]; then
            reset_strikes
            exit 0
          fi

          strikes=0
          if [ -f "$strikes_file" ]; then strikes=$(cat "$strikes_file"); fi
          strikes=$(( strikes + 1 ))
          echo "$strikes" > "$strikes_file"
          log "cache is ''${age}s stale (limit ''${STALE}s) - strike ''${strikes}/''${STRIKES_NEEDED}"
          if [ "$strikes" -lt "$STRIKES_NEEDED" ]; then exit 0; fi

          if [ -f "$restart_file" ]; then
            last=$(cat "$restart_file")
            if [ $(( now - last )) -lt "$COOLDOWN" ]; then
              log "in cooldown since ''${last}, not restarting"
              exit 0
            fi
          fi

          log "MeetingBar is wedged - restarting"
          /usr/bin/osascript -e 'tell application id "leits.MeetingBar" to quit' \
            >/dev/null 2>&1 || true
          for _ in 1 2 3 4 5 6 7 8 9 10; do
            running || break
            sleep 1
          done
          if running; then
            log "graceful quit timed out - terminating"
            /usr/bin/pkill -x MeetingBar || true
            sleep 2
          fi

          /usr/bin/open -b leits.MeetingBar \
            || /usr/bin/open -a "/Applications/Nix Apps/MeetingBar.app"

          date +%s > "$restart_file"
          reset_strikes
          log "MeetingBar relaunched"
        '';
      };
    in
    {
      home.packages = [ watchdog ];

      launchd.agents.meetingbar-watchdog = {
        enable = true;
        config = {
          ProgramArguments = [ "${watchdog}/bin/meetingbar-watchdog" ];
          RunAtLoad = true;
          StartInterval = checkInterval;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/meetingbar-watchdog.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/meetingbar-watchdog.log";
        };
      };
    };
}
