# Neovide — GUI Neovim frontend (smooth cursor animation, ligatures, GPU
# rendering). It launches the `nvim` on PATH, so it inherits the full nixvim
# config for free.
#
# The font is intentionally NOT set here: stylix already themes Neovide's font
# (MesloLGS Nerd Font Mono, matching every other themed app). macFonts installs
# that font so macOS can actually resolve it. On darwin the package ships
# Applications/Neovide.app, which home-manager links into
# ~/Applications/Home Manager Apps → Spotlight-launchable.
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
