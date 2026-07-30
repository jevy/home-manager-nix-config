# Stylix theming (cross-platform)
{ inputs, ... }:
let
  stylixConfig =
    { pkgs, ... }:
    {
      stylix = {
        enable = true;
        image = pkgs.callPackage ../../pkgs/lowpoly-wallpaper { };
        base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-soft.yaml";
        opacity.popups = 0.9;

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

      # Stylix's kmscon target sets services.kmscon.{extraConfig,fonts}, which
      # were removed in nixpkgs unstable. Keep it disabled. NixOS-only: the
      # home-manager stylix module has no kmscon target, so this can't live in
      # the shared stylixConfig.
      stylix.targets.kmscon.enable = false;

      # Stylix's regreet target sets programs.regreet.*, renamed in nixpkgs
      # unstable to services.displayManager.regreet — every rebuild prints an
      # obsolete-option trace. We use tuigreet (see desktop/hyprland.nix), not
      # regreet, so disable the target. TODO: drop once stylix migrates to the
      # new option path.
      stylix.targets.regreet.enable = false;
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
