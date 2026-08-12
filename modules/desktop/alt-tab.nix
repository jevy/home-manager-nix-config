# AltTab — keyboard window selection on macOS.
#
# A window picker, alongside modules/desktop/aerospace.nix. AeroSpace owns
# layout, workspaces and directional focus ($mod+H/J/K/L, the Hyprland motion);
# this is the other way of reaching a window, and the two do different jobs.
#
# HISTORY: AltTab arrived when the layout tool was Rectangle, which could place
# the focused window but never change which window was focused — so a picker was
# the only way to select anything by keyboard. That header also recorded
# AeroSpace and yabai as "rejected in favour of staying native"; AeroSpace won
# the rematch (it needs no SIP changes, unlike yabai), and Rectangle is gone.
#
# WHY IT SURVIVED THE SWITCH. AeroSpace's `focus` is spatial and stays inside
# the current workspace — it answers "the window to my left". AltTab answers
# "that window, wherever it is": every window on every workspace and Space,
# including minimized and hidden ones, with preview thumbnails, ranked by
# recency rather than position. Hold ⌥, Tab/arrow to it, release to focus.
#
# Default shortcut is ⌥Tab, which collides with nothing: macOS itself uses
# ⌘Tab, and aerospace.nix confines itself to the ⌃⌥⌘ and ⌃⌥⇧⌘ tiers — it
# deliberately avoids the bare ⌥ tier that AeroSpace's own default config uses,
# precisely so this binding stays free.
#
# WHY SHORTCUTS ARE NOT SET HERE. AltTab stores each shortcut as a dictionary
# of { string representation, NSKeyedArchiver-encoded Data blob } — see
# shortcutStorage() in src/preferences/Preferences.swift. The Data field is an
# archived Swift object, so a shortcut cannot be expressed as plain plist
# values — nothing like the plain TOML aerospace.nix generates. Rebinding is
# therefore left to AltTab's own preferences UI; only the plain-string
# preferences below are declared.
#
# That is also why this module uses per-key `defaults write` rather than a
# whole-domain `defaults import`. Import REPLACES the domain,
# which would wipe any shortcut rebound in the UI on every rebuild — the one
# thing that must survive here, since it cannot be declared. Writing key by
# key touches only the keys below and leaves the shortcut dictionaries alone.
#
# NAVIGATION once the switcher is open is handled by vimKeysEnabled below —
# h/j/k/l move the selection, release the hold key to focus. That needs no
# rebinding at all, so the only shortcut worth changing in the UI is the hold
# shortcut itself — and there is now nowhere better for it to go. BOTH ⌃⌥⌘ and
# ⌃⌥⇧⌘ are taken by aerospace.nix (select and move), so the ⌥ tier this already
# sits on is the last one free. Keep ⌥Tab.
#
# Do not put the hold shortcut on plain ⌥ combined with a letter as the next
# key: ⌥+letter types special characters (⌥L is ¬) and AltTab would intercept
# those globally. ⌥ with Tab — the default — is fine. Note that AeroSpace's own
# default config binds alt-tab to workspace-back-and-forth; aerospace.nix does
# not use that tier at all, so there is no conflict, but do not copy upstream
# AeroSpace bindings in wholesale without checking this.
#
# Preference values are all STRINGS, including numbers and booleans — enum
# preferences are stored as the case's index, also as a string (verified
# against Preferences.swift / MacroPreferences.swift at 11.4.3).
#
# Preferences are pushed with `defaults` rather than home.file because macOS
# reads preference domains through cfprefsd, and cfprefsd does not follow
# symlinks. home.file installs a symlink into the Nix store, and with that in
# place `defaults read com.lwouis.alt-tab-macos` reports "domain does not
# exist", while the identical bytes copied to a real file read back fine — so
# the app starts with none of the configuration applied (verified 2026-08-10
# against the equivalent Rectangle plist, home-manager cbb7767). Handing the
# values to cfprefsd through `defaults` is the supported path.
#
# aerospace.nix needs none of this: AeroSpace takes a --config-path on the
# command line and reads the file directly, so its config is a plain store
# path with no plist and no activation script.
#
# Needs two permissions granted once, on first launch, neither grantable from
# Nix: Accessibility (to focus windows) and Screen Recording (for the window
# preview thumbnails; without it AltTab still switches but shows blank tiles).
# Launch from /Applications/Nix Apps, which nix-darwin aliases and Spotlight
# indexes — see environment.systemPackages in the mac-work host.
{ ... }:
{
  flake.modules.homeManager.altTab =
    { pkgs, lib, ... }:
    let
      # Enum preferences are stored as the case index, stringified.
      # SpacesToShowPreference:  all | visible | nonVisible
      spacesAll = "0";
      # ScreensToShowPreference: all | showingAltTab
      screensAll = "0";
      # ShowHowPreference:       show | hide | showAtTheEnd
      showHowShow = "0";

      prefs = {
        # Show every window, on every Space and every screen — the whole point
        # is to reach a window without first finding its Space.
        spacesToShow = spacesAll;
        screensToShow = screensAll;
        showMinimizedWindows = showHowShow;
        showHiddenWindows = showHowShow;
        showFullscreenWindows = showHowShow;

        # Default is "100" ms before the switcher appears. Zero makes a quick
        # ⌥Tab tap feel instant, which is the whole reason for choosing a
        # native tool over a window manager here.
        windowDisplayDelay = "0";

        menubarIconShown = "true";

        # Navigate the open switcher with h/j/k/l. Off by default upstream;
        # on here because it is the whole point — it restores the Hyprland
        # hand position for choosing a window, without needing any of the
        # shortcuts rebound (which cannot be done declaratively anyway).
        # Arrow keys stay on alongside it as the discoverable fallback.
        vimKeysEnabled = "true";
        arrowKeysEnabled = "true";
      };

      # Every AltTab preference is stored as a string, including the numeric
      # and boolean ones — see the note above.
      writes = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          k: v: ''run /usr/bin/defaults write com.lwouis.alt-tab-macos ${k} -string ${lib.escapeShellArg v}''
        ) prefs
      );
    in
    {
      home.packages = [ pkgs.alt-tab-macos ];

      home.activation.altTabPrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${writes}
        # cfprefsd caches the domain; without this the running daemon keeps
        # serving the pre-write values to the next AltTab launch.
        run /usr/bin/killall cfprefsd 2>/dev/null || true
        # AltTab reads its preferences at startup, so a running instance has
        # to be restarted to see them. Every step is best-effort: activation
        # runs under `darwin-rebuild switch`, i.e. sudo, where LaunchServices
        # has no user GUI session to open into and `open` fails with -600.
        # An unguarded failure there aborts the whole activation and silently
        # skips every later entry (this happened on 2026-08-10, which is why
        # the guards are here).
        if /usr/bin/pgrep -qf 'AltTab.app/Contents/MacOS/AltTab' 2>/dev/null; then
          run /usr/bin/killall AltTab 2>/dev/null || true
          run /usr/bin/open -a "/Applications/Nix Apps/AltTab.app" 2>/dev/null || true
        fi
      '';
    };
}
