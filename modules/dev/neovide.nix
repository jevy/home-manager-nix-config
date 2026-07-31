# Neovide — GUI Neovim frontend (smooth cursor animation, ligatures, GPU
# rendering). It launches the `nvim` on PATH, so it inherits the full nixvim
# config for free.
#
# The font is intentionally NOT set here: stylix already themes Neovide's font
# (MesloLGS Nerd Font Mono, matching every other themed app). macFonts installs
# that font so macOS can actually resolve it. On darwin the package ships
# Applications/Neovide.app; to make it Spotlight-launchable it's also listed in
# the mac-work host's environment.systemPackages, which nix-darwin aliases into
# /Applications/Nix Apps (see modules/hosts/mac-work/default.nix).
{ ... }:
{
  flake.modules.homeManager.neovide =
    { ... }:
    {
      programs.neovide = {
        enable = true;
        settings = {
          fork = true; # detach from the launching shell so the prompt returns
        };
      };

      home.shellAliases.v = "neovide";
    };
}
