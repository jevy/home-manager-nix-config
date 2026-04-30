# Kanata keyboard remapping (home row mods)
# Idea from https://github.com/dreamsofcode-io/home-row-mods
#
# Layout summary:
#   CapsLock        → tap = Esc, hold = Ctrl  (caps2esc, replaces xkb ctrl:nocaps)
#   Home row holds  → a=alt, s=meta, d=shift, e=nav-layer, f=ctrl
#                     j=ctrl, k=shift, l=meta, ;=alt
#   j+k chord       → Esc  (vim-friendly, works alongside home row mods)
#   Nav layer (hold e):
#     h = Left, j = Ctrl+Backspace (delete word), k = Backspace, l = Right
{ ... }:
{
  flake.modules.nixos.kanata =
    { ... }:
    {
      services.kanata = {
        enable = true;
        keyboards = {
          internalKeyboard = {
            devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
            extraDefCfg = "process-unmapped-keys yes\n  concurrent-tap-hold yes";
            config = ''
              (defsrc
               caps a s d e f h j k l ;
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
               ;; CapsLock: tap=esc, hold=ctrl
               cec (tap-hold 200 200 esc lctl)

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
               @cec @a  @s  @d  @e  @f  h   @j  @k  @l  @;
              )
              (deflayer nav
               _   _   _   _   _   _   left C-bspc bspc right _
              )
            '';
          };
        };
      };
    };
}
