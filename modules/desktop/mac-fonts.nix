# Fonts for macOS (home-manager).
#
# On NixOS, base/fonts.nix installs the Nerd Fonts system-wide via
# fonts.packages + fontconfig. macOS has no fontconfig and does NOT read
# ~/.nix-profile/share/fonts, so packages there stay invisible to CoreText.
# home-manager bridges this on darwin: any font package in home.packages is
# linked into ~/Library/Fonts/HomeManager, which macOS scans. So home.packages
# alone is enough — no manual ~/Library/Fonts linking needed.
#
# This makes "MesloLGS Nerd Font" actually resolve for Ghostty (which already
# requests it) and Neovide.
{ ... }:
{
  flake.modules.homeManager.macFonts =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        nerd-fonts.meslo-lg
        nerd-fonts.symbols-only
      ];
    };
}
