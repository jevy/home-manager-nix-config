# Kanata keyboard remapping (home row mods)
# Idea from https://github.com/dreamsofcode-io/home-row-mods
#
# Layout summary:
#   CapsLock        → Esc (no hold; Ctrl-on-hold removed to spare left pinky)
#   Home row holds  → a=alt, s=meta, d=shift, e=nav-layer, f=ctrl
#                     j=ctrl, k=shift, l=meta, ;=alt
#   j+k chord       → Esc  (vim-friendly, works alongside home row mods)
#   Nav layer (hold e):
#     h = Left, j = Down, k = Up, l = Right (vim hjkl arrows)
#     u = Ctrl+Backspace (delete word), i = Backspace
#
# Ulnar-nerve note (2026-05): CapsLock's hold-as-Ctrl was removed to spare
# the left pinky. Physical LeftShift/LeftCtrl/LeftMeta are kept native
# because same-hand chords (e.g. Ctrl+Shift+V, Meta+Shift+1) can't be
# expressed via home-row mods.
#
# RightAlt → LeftMeta: gives a right-thumb Super key. Hyprland uses Super
# for workspace switching (Super+1..4 = ~210/day in the keystroke log), so
# moving that load off the left ring finger onto the right thumb is the
# single biggest ergonomic win available.
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
     ralt
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

     ;; Home row mods
     a (tap-hold-release-keys $tap-time $hold-time a lalt $left-hand-keys)
     s (tap-hold-release-keys $tap-time $hold-time s lmet $left-hand-keys)
     d (tap-hold-release-keys $tap-time $hold-time d lsft $left-hand-keys)
     e (tap-hold-release-keys $tap-time $hold-time e (layer-while-held nav) $left-hand-keys)
     f (tap-hold-release-keys $tap-time $hold-time f lctl $left-hand-keys)
     j (tap-hold-release-keys $tap-time $hold-time j rctl $right-hand-keys)
     k (tap-hold-release-keys $tap-time $hold-time k rsft $right-hand-keys)
     l (tap-hold-release-keys $tap-time $hold-time l rmet $right-hand-keys)
     ; (tap-hold-release-keys $tap-time $hold-time ; ralt $right-hand-keys)
    )
    ;; j+k chord = esc
    (defchordsv2
     (j k) esc 75 first-release ()
    )
    (deflayer base
     @cec @a  @s  @d  @e  @f  h   @j  @k  @l  @;  u      i
     lmet
    )
    (deflayer nav
     _   _   _   _   _   _   left down up   right _   C-bspc bspc
     _
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
    {
      xdg.configFile."kanata/config.kbd".text = configFile;

      systemd.user.services.kanata = {
        Unit = {
          Description = "Kanata keyboard remapper (home row mods)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.kanata}/bin/kanata --cfg %h/.config/kanata/config.kbd";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
