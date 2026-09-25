# Kanata keyboard remapping (home row mods)
# Idea from https://github.com/dreamsofcode-io/home-row-mods
#
# Layout summary:
#   CapsLock        → Esc (no hold; Ctrl-on-hold removed to spare left pinky)
#   Home row holds  → a=alt, s=$mod, d=shift, e=nav-layer, f=ctrl
#                     j=ctrl, k=shift, l=$mod, ;=alt
#   LeftMeta        → $mod  (bottom-left, was native Super)
#   RightAlt        → $mod  (right thumb)
#   j+k chord       → Esc  (vim-friendly, works alongside home row mods)
#   Nav layer (hold e):
#     h = Left, j = Down, k = Up, l = Right (vim hjkl arrows)
#     u = Ctrl+Backspace (delete word), i = Backspace
#
# Ulnar-nerve note (2026-05): CapsLock's hold-as-Ctrl was removed to spare
# the left pinky. Physical LeftShift/LeftCtrl are kept native because
# same-hand chords (e.g. Ctrl+Shift+V) can't be expressed via home-row mods.
#
# LeftMeta used to be native for the same reason (Meta+Shift+1). It isn't
# any more: bare Super stopped being a modifier anything binds once $mod
# became Ctrl+Alt+Super, so the key was dead. It now sends the whole stack,
# which makes Meta+Shift+1 into $mod+Shift+1 — the same move-to-workspace
# it always was.
#
# RightAlt → Ctrl+Alt+Super: gives a right-thumb $mod key. Hyprland uses
# Super for workspace switching (Super+1..4 = ~210/day in the keystroke log),
# so moving that load off the left ring finger onto the right thumb is the
# single biggest ergonomic win available.
#
# It sends all three because hyprland's $mod became Ctrl+Alt+Super, matching
# the mac's ctrl-alt-cmd (see modules/desktop/hyprland.nix). Bare lmet here
# would no longer fire any window bind. The internal keyboard has no single
# key that expands to the stack the way the Voyager does, so kanata
# synthesises it with `multi`, via the @mod alias.
#
# Four keys reach $mod, for different hand positions: the right thumb
# (RightAlt), the bottom-left LeftMeta, and s-hold / l-hold on the home row.
# s and l held the now-dead bare Super, so nothing was displaced. Note that
# l-hold cannot produce $mod+L (focus right) — it is the same key — so use
# the thumb, LeftMeta or s-hold for the hjkl focus binds.
#
# SCOPE: this covers the INTERNAL keyboard only — linux-dev below pins it to
# platform-i8042-serio-0-event-kbd. The Voyager is firmware-owned (Oryx) on
# every host, so nothing here applies to it.
#
# The Voyager carries a split kanata cannot express, because it exists to
# reconcile Linux with macOS:
#
#   f-hold / j-hold  -> the APP-command modifier. Ctrl on the Linux layer, ⌘ on
#                       the Mac layer. Makes every GUI chord one identical
#                       motion across hosts (f+L is Ctrl+L in Firefox on Linux
#                       and ⌘L here; f+C copies on both).
#   right thumb      -> plain Ctrl on BOTH layers, for terminal control codes.
#                       Needed because the Mac layer spends f/j on ⌘ and would
#                       otherwise have no Ctrl at all; a thumb because Ctrl+A/C/
#                       D/R/W/E are left-hand letters and f-hold cannot reach R
#                       or V (same finger — they sit directly above and below f).
#
# On this keyboard f/j stay plain Ctrl and there is no thumb cluster to give
# the second role to, so the laptop is deliberately the odd one out. See the
# keyboard block in modules/hosts/mac-work/default.nix for the macOS half and
# why no hidutil Ctrl↔⌘ remap belongs there.
#
# Runs as a per-user (home-manager) service tied to graphical-session.target,
# NOT a system service. A system-level kanata grabs (EVIOCGRAB) the keyboard
# at boot, before login — which breaks the regreet/cage greeter (the greeter
# binds the grabbed, silent physical keyboard; a stuck key then makes regreet
# auto-resubmit in a loop). Starting kanata only after login leaves the greeter
# with the plain keyboard, and the grab is released on logout (PartOf=).
{ ... }:
let
  configFile = ''
    (defcfg
     process-unmapped-keys yes
     concurrent-tap-hold yes
     linux-dev /dev/input/by-path/platform-i8042-serio-0-event-kbd)
    (defsrc
     caps a s d e f h j k l ; u i
     lmet ralt
    )
    (defvar
     tap-time 150
     hold-time 250
     left-hand-keys (
       q w e r t
       a s d f g
       z x c v b
       spc ret  ;; letter + space/enter always taps
     )
     right-hand-keys (
       y u i o p
       h j k l ;
       n m , . /
       spc ret  ;; letter + space/enter always taps
     )
    )
    (defalias
     ;; CapsLock: tap = Esc only. Ctrl-on-hold removed — use f-hold.
     cec esc

     ;; Hyprland's $mod, as one action: Ctrl+Alt+Super (see
     ;; modules/desktop/hyprland.nix). Left-hand variants on both hands so the
     ;; modmask is identical whichever key produced it.
     mod (multi lctl lalt lmet)

     ;; Home row mods
     a (tap-hold-release-keys $tap-time $hold-time a lalt $left-hand-keys)
     s (tap-hold-release-keys $tap-time $hold-time s @mod $left-hand-keys)
     d (tap-hold-release-keys $tap-time $hold-time d lsft $left-hand-keys)
     e (tap-hold-release-keys $tap-time $hold-time e (layer-while-held nav) $left-hand-keys)
     f (tap-hold-release-keys $tap-time $hold-time f lctl $left-hand-keys)
     j (tap-hold-release-keys $tap-time $hold-time j rctl $right-hand-keys)
     k (tap-hold-release-keys $tap-time $hold-time k rsft $right-hand-keys)
     l (tap-hold-release-keys $tap-time $hold-time l @mod $right-hand-keys)
     ; (tap-hold-release-keys $tap-time $hold-time ; ralt $right-hand-keys)
    )
    ;; j+k chord = esc
    (defchordsv2
     (j k) esc 75 first-release ()
    )
    (deflayer base
     @cec @a  @s  @d  @e  @f  h   @j  @k  @l  @;  u      i
     @mod @mod
    )
    (deflayer nav
     _   _   _   _   _   _   left down up   right _   C-bspc bspc
     _    _
    )
  '';
in
{
  # System side: only ensure /dev/uinput exists and is group-accessible.
  # (jevin is already in the input + uinput groups via modules/base/user.nix.)
  flake.modules.nixos.kanata =
    { ... }:
    {
      hardware.uinput.enable = true;
    };

  # User side: run kanata inside the graphical session, after login.
  flake.modules.homeManager.kanata =
    { pkgs, ... }:
    let
      # The config goes in the store and ExecStart names that store path
      # directly. NOT %h/.config/kanata/config.kbd.
      #
      # kanata reads its config once at startup and has no hot-reload, so a
      # keymap edit only takes effect when the service restarts. home-manager
      # has startServices = true, which restarts units whose UNIT FILE changed
      # — and with a %h path the unit file is byte-identical no matter what the
      # keymap says, so the symlink underneath silently changed while the old
      # process kept running the config it read at boot. Cost an hour of
      # "I rebuilt but s-hold does nothing" on 2026-09-24.
      #
      # Naming the store path puts the config's hash in ExecStart, so any
      # keymap edit changes the unit and sd-switch restarts it.
      cfg = pkgs.writeText "kanata-config.kbd" configFile;
    in
    {
      # Kept so the config is readable at a stable path for inspection and
      # `kanata --cfg ~/.config/kanata/config.kbd --check`. It is NOT what the
      # service reads.
      xdg.configFile."kanata/config.kbd".source = cfg;

      systemd.user.services.kanata = {
        Unit = {
          Description = "Kanata keyboard remapper (home row mods)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.kanata}/bin/kanata --cfg ${cfg}";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
