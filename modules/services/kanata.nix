# Kanata keyboard remapping (home row mods)
# Idea from https://github.com/dreamsofcode-io/home-row-mods
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
            extraDefCfg = "process-unmapped-keys yes";
            config = ''
              (defsrc
               a s d e f h j k l ;
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
              (deflayer base
               @a  @s  @d  @e  @f  h   @j  @k  @l  @;
              )
              (deflayer nav
               _   _   _   _   _   left down up right _
              )
            '';
          };
        };
      };
    };
}
