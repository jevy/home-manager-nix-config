# Which desktop shell the Linux desktop runs on Hyprland:
#   "legacy"   ashell bar, mako, rofi, hyprlock (ashell.nix, mako.nix, ...)
#   "noctalia" Noctalia v5 (modules/desktop/noctalia.nix)
#
# Declared in both module systems so NixOS config (PAM) and home-manager config
# (bar, binds) can each read it. Set it ONCE, on the NixOS side, in
# modules/hosts/linux-desktop-base.nix. That file mirrors the NixOS value into
# home-manager, so the two sides can never disagree.
#
# Temporary. Once Noctalia has run clean for about two weeks, the legacy stack
# and this switch get deleted. Design:
# docs/superpowers/specs/2026-10-03-noctalia-shell-design.md
{ ... }:
let
  option =
    lib:
    lib.mkOption {
      type = lib.types.enum [
        "legacy"
        "noctalia"
      ];
      default = "legacy";
      description = "Desktop shell stack for Hyprland.";
    };
in
{
  flake.modules.nixos.desktopShell =
    { lib, ... }:
    {
      options.desktopShell = option lib;
    };

  flake.modules.homeManager.desktopShell =
    { lib, ... }:
    {
      options.desktopShell = option lib;
    };
}
