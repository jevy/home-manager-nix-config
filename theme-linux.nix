{
  pkgs,
  config,
  stylix,
  ...
}: let
  base16-schemes = pkgs.fetchFromGitHub {
    owner = "tinted-theming";
    repo = "base16-schemes";
    rev = "2b6f2d0677216ddda50c9cabd6ee70fae4665f81";
    sha256 = "1pb979mwamg82pkx0bnim9sw129jvswialrsgarn9qa25mk36dsm";
  };
in {
  stylix.base16Scheme = "${base16-schemes}/gruvbox-material-dark-soft.yaml";
  stylix.enable = true;

  stylix.image = ./backgrounds/j5vziuan8tra1.jpg;
  stylix.polarity = "dark";
  home-manager.sharedModules = [
    {
      stylix.enable = true;
      stylix.targets.gtk.enable = false;
      stylix.targets.firefox.enable = false;
    }
  ];

  # wayland.windowManager.sway.config =
  # {
  #   output = {
  #     "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344".bg = "~/.config/backgrounds/rocket.png fit";
  #     "Unknown 0x5A2D 0x00000000".bg = "~/.config/backgrounds/rocket.png fit";
  #   };
  # };
}
