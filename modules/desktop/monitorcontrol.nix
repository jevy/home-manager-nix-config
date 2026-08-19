# MonitorControl — brightness/volume for external displays on macOS.
#
# THE PROBLEM. macOS has never spoken DDC/CI. Its native brightness slider only
# addresses backlights it can drive directly: the built-in panel, and the small
# set of Apple-blessed USB-C displays (Studio Display, Pro Display XDR, LG
# UltraFine) that expose brightness over the DisplayPort AUX channel the way
# Apple expects. A Dell exposes brightness only as the DDC/CI VCP feature 0x10
# over the display cable, and macOS never emits that command — so the slider has
# nothing to attach to and either vanishes or moves the internal screen only.
#
# nix-darwin cannot fix this and does not try. The single brightness string in
# the whole nix-darwin tree is system.defaults.controlcenter.Display (18 = show
# the slider icon in the menu bar, 24 = hide it) — menu bar chrome, not a
# backlight. There is no DDC option anywhere, and no home-manager or nix-darwin
# service module exists for MonitorControl, Lunar or BetterDisplay. So the app
# is a bare install plus a hand-granted permission, whichever route it takes.
#
# WHY HOMEBREW AND NOT pkgs.monitorcontrol. nixpkgs HAS it — monitorcontrol
# 4.3.3, MIT, aarch64-darwin, unpacked from upstream's release DMG. It was
# rejected on measured evidence. Built and inspected 2026-08-19:
#
#   $ codesign -dvvv .../MonitorControl.app
#   CodeDirectory ... flags=0x20002(adhoc,linker-signed)
#   Signature=adhoc
#   TeamIdentifier=not set
#   Sealed Resources=none
#
#   $ codesign --verify MonitorControl.app
#   code has no resources but signature indicates they must be present
#   $ spctl -a -t exec MonitorControl.app
#   (rejected)
#
# The vendor's Developer ID signature does not survive nixpkgs' packaging: the
# app arrives ad-hoc-signed with a broken resource seal, and Gatekeeper rejects
# it outright. That is fatal for THIS app specifically, because its whole job
# needs an Accessibility grant. TCC anchors a grant on the app's designated
# requirement; with no Team ID and no valid seal there is nothing stable to
# anchor to, so it degrades to path plus cdhash — and BOTH change on every
# version bump of a store-path app. Re-granting Accessibility after each update
# is then the expected behaviour, not a risk. A cask drops the vendor-signed
# bundle into /Applications with its Developer ID intact, and the grant
# persists. This is the narrow case where Homebrew is the better tool.
#
# (Same reasoning does not transfer to the other two: lunar and betterdisplay
# are both unfree, and betterdisplay's brightness control is incidental to its
# HiDPI/scaling feature set. MonitorControl is the free, single-purpose one.)
#
# THE TWO HOMEBREW LAYERS, which are routinely conflated:
#
#   homebrew.*  (nix-darwin builtin, used here)  generates a Brewfile and runs
#               `brew bundle` on activation. Explicitly does NOT install
#               Homebrew — upstream's own option description says so.
#   nix-homebrew (github:zhaofengli/nix-homebrew, NOT used)  installs and pins
#               Homebrew itself plus declarative taps as flake inputs, and
#               manages no packages at all. Designed to compose with the above,
#               not replace it.
#
# nix-homebrew is deliberately skipped. Homebrew is ALREADY INSTALLED on
# mac-work — /opt/homebrew, Homebrew 6.0.13 as of 2026-08-19 — so its one job is
# already done, and pinning the brew version and tap revisions to flake.lock
# does not earn a new flake input for a single signed cask. Add it if the brew
# surface ever grows enough that a drifting Homebrew becomes the thing that
# breaks rebuilds.
#
# WHAT WAS ALREADY THERE, and why cleanup is "none". That pre-existing Homebrew
# had two casks installed by hand: 1password-cli and claude-code. BOTH ARE
# ALREADY NIX-MANAGED on this host — homeManager.onepasswordCli and
# homeManager.claudeCode in modules/hosts/mac-work/default.nix. Nix wins today
# only by accident: nix-darwin's programs.zsh.enable does not run
# `brew shellenv`, so /opt/homebrew/bin is not on PATH at all and the brew
# copies are unreachable dead weight.
#
# cleanup has four values in the pinned nix-darwin: "none" (leave undeclared
# packages alone), "check" (activation FAILS listing them), "uninstall" and
# "zap" (remove them). "check" is the right end state and the wrong starting
# point — with those two casks present it would abort the very next
# `rebuildhm`, and a failed activation applies no other configuration change
# either, so an unrelated rebuild would be held hostage to a monitor module.
# So this starts at "none". Escalate to "check" only after
# `brew uninstall --cask 1password-cli claude-code` has resolved the
# duplicates; do not skip to "uninstall", which would delete them silently
# rather than naming them.
#
# THE COST OF THIS ROUTE, stated plainly: nix-darwin runs `brew bundle` during
# activation, so a Homebrew or tap failure becomes a `rebuildhm` failure rather
# than an isolated `brew` failure. Keep the cask list minimal for that reason —
# every cask added here is one more thing that can break an unrelated rebuild.
#
# The casks list below merges with any other module's, so a future cask belongs
# in its own feature module rather than appended here.
#
# NOT SET GREEDY, DELIBERATELY. The cask is marked auto_updates upstream:
# MonitorControl updates itself, so `brew upgrade` skips it unless greedy = true.
# Leave it self-updating — that is precisely what keeps the vendor signature (and
# therefore the Accessibility grant) intact, which is the entire reason for
# choosing the cask over the nixpkgs build.
#
# AFTER THE FIRST REBUILD, two things are needed by hand and neither is
# declarable from Nix:
#   1. Grant Accessibility on first launch (System Settings → Privacy &
#      Security → Accessibility). Without it MonitorControl runs but cannot
#      capture the brightness keys.
#   2. Turn on "Start at login" in its own preferences — that writes an
#      SMAppService registration, same limitation recorded in
#      modules/apps/meetingbar.nix.
#
# AND CHECK THE MONITOR'S OWN OSD FIRST. Dell hides DDC/CI under
# Menu → Others → DDC/CI and some models ship with it OFF. With it off, no
# software on this list can do anything. Two further failure modes worth knowing
# before blaming this module: DDC frequently does not survive a dock or hub
# (connect the display straight to the Mac), and DDC over HDMI has been broken
# on some Apple Silicon machines — DisplayPort/USB-C is the better-behaved link.
{ ... }:
{
  flake.modules.darwin.monitorcontrol = { ... }: {
    homebrew = {
      enable = true;

      # "none" is a migration state, not the goal — see the cleanup note above
      # before changing it.
      onActivation.cleanup = "none";

      casks = [ "monitorcontrol" ];
    };
  };
}
