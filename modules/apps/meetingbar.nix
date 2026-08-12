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
{ ... }:
{
  flake.modules.darwin.meetingbar =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.meetingbar ];
    };
}
