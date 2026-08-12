# Key-event inspection tools for mac-work — for working out what a custom
# keyboard layout actually sends, so AeroSpace bindings can be aimed at it.
#
# THE PROBLEM THESE SOLVE. AeroSpace binding names like `ctrl-alt-cmd-h` refer
# to PHYSICAL key positions, resolved through key-mapping.preset (qwerty by
# default, with dvorak and colemak also built in — see
# modules/desktop/aerospace.nix). On a custom layout, the letter printed on the
# keycap, the character macOS produces, and the key code AeroSpace matches on
# are three different things. Guessing at that is how you end up with a binding
# that silently never fires.
#
# TWO TOOLS, BECAUSE THERE ARE TWO DIFFERENT QUESTIONS:
#
#   "What is this key, really?"       -> Karabiner-EventViewer
#     Raw HID usage page/usage, the macOS key code name, and modifier flags,
#     one row per event. This is the one that answers which key code a keycap
#     maps to, and therefore what to put in an AeroSpace binding. Passive
#     observer only — it is NOT the Karabiner remapper (see
#     pkgs/karabiner-eventviewer.nix for why only this app is installed).
#
#   "Did my chord land at all?"       -> KeyCastr
#     An on-screen overlay of keystrokes as macOS resolved them, modifier
#     glyphs included. Good for confirming a four-modifier stack like ⌃⌥⇧⌘H
#     arrives intact rather than being eaten by the OS or another app, and for
#     watching what a layer on a programmable keyboard emits in real time.
#
# ONCE YOU KNOW THE KEY CODES. If the layout does not match any built-in
# preset, AeroSpace takes a full custom table rather than forcing a choice
# between qwerty/dvorak/colemak — key-mapping.key-notation-to-key-code, which
# maps each binding notation name to the physical key code it should match.
# Confirmed present in 0.21.2-Beta. Add it under settings in
# modules/desktop/aerospace.nix, e.g.
#
#   key-mapping.key-notation-to-key-code = { h = "h"; j = "n"; };
#
# meaning "when a binding says h, match the physical key that qwerty calls h".
# Verify afterwards with `aerospace reload-config --dry-run
# --warnings-as-errors`, then `aerospace trigger-binding` to fire a binding
# without pressing anything.
#
# PERMISSIONS, granted once by hand, neither grantable from Nix:
#   Karabiner-EventViewer  Input Monitoring
#   KeyCastr               Accessibility (and Input Monitoring on newer macOS)
#
# Both are declared as SYSTEM packages rather than home-manager ones, for the
# same reason AltTab is: nix-darwin aliases environment.systemPackages into
# /Applications/Nix Apps, the only location LaunchServices indexes — and an app
# it will not index cannot be picked in the permission dialogs above. See the
# header of modules/hosts/mac-work/default.nix.
#
# These are diagnostic tools, not daemons. Nothing here starts at login; launch
# them when a binding misbehaves and quit them after.
{ ... }:
{
  flake.modules.darwin.keyInspect =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.callPackage ../../pkgs/karabiner-eventviewer.nix { })
        pkgs.keycastr
      ];
    };
}
