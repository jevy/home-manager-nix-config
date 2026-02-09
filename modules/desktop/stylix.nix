# Stylix theming (cross-platform)
{ inputs, ... }:
let
  stylixConfig =
    { pkgs, ... }:
    {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-soft.yaml";

        fonts = {
          serif = {
            package = pkgs.dejavu_fonts;
            name = "DejaVu Serif";
          };
          sansSerif = {
            package = pkgs.dejavu_fonts;
            name = "DejaVu Sans";
          };
          monospace = {
            package = pkgs.nerd-fonts.meslo-lg;
            name = "MesloLGS Nerd Font Mono";
          };
          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };
        };
      };
    };
in
{
  # NixOS stylix
  flake.modules.nixos.stylix =
    { pkgs, ... }:
    {
      imports = [
        inputs.stylix.nixosModules.stylix
        stylixConfig
      ];
    };

  # Home-manager stylix (for macOS standalone)
  flake.modules.homeManager.stylix =
    { pkgs, ... }:
    {
      imports = [
        inputs.stylix.homeModules.stylix
        stylixConfig
      ];
    };
}
