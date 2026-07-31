# Make home-manager GUI apps discoverable by Spotlight.
#
# home-manager links .app bundles into ~/Applications as symlinks pointing into
# /nix/store, but macOS Spotlight / LaunchServices refuse to index symlinked
# app bundles — so Ghostty, Neovide, Linear, etc. never appear in Spotlight
# search. This is the same problem nix-darwin solves with a "trampoline": use
# `mkalias` to create *real* macOS alias files (which Spotlight does index)
# pointing at the store apps.
#
# The aliases live in their own folder, rebuilt from scratch on every
# activation so removed apps don't leave stale entries.
{ ... }:
{
  flake.modules.homeManager.macAppAliases =
    { config, pkgs, lib, ... }:
    {
      home.activation.aliasHomeManagerApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        aliasDir="${config.home.homeDirectory}/Applications/Home Manager Aliases"
        $DRY_RUN_CMD rm -rf "$aliasDir"
        $DRY_RUN_CMD mkdir -p "$aliasDir"
        for app in "${config.home.path}/Applications/"*.app; do
          [ -e "$app" ] || continue
          target="$(${pkgs.coreutils}/bin/readlink -f "$app")"
          name="$(${pkgs.coreutils}/bin/basename "$app")"
          $DRY_RUN_CMD ${pkgs.mkalias}/bin/mkalias "$target" "$aliasDir/$name"
        done
      '';
    };
}
