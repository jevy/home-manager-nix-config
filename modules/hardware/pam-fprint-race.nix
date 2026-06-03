# Race fingerprint and password for polkit prompts.
#
# Stock PAM is serial: pam_fprintd runs first, blocks ~6 s waiting for a
# finger, then falls through to pam_unix. So password unlock is slow.
# pam_fprint_grosshack forks internally and races the fingerprint reader
# against the password conversation; whichever the user produces first
# wins, the other is cancelled.
#
# Hyprlock already handles this itself via fprintd's D-Bus API
# (hyprwm/hyprlock#514), so its PAM stack stays untouched. greetd has
# fprintd disabled (see modules/desktop/hyprland.nix). polkit-1 is the
# remaining spot — used by hyprpolkitagent for 1Password CLI elevation,
# sudo via GUI apps, etc.
#
# Track: https://github.com/hyprwm/hyprpolkitagent/issues/24
{ ... }:
{
  flake.modules.nixos.pamFprintRace =
    { pkgs, ... }:
    let
      pam_fprint_grosshack = pkgs.callPackage ../../pkgs/pam_fprint_grosshack.nix { };
    in
    {
      security.pam.services.polkit-1 = {
        fprintAuth = false;
        rules.auth.grosshack = {
          order = 11500;
          control = "sufficient";
          modulePath = "${pam_fprint_grosshack}/lib/security/pam_fprintd_grosshack.so";
        };
      };
    };
}
