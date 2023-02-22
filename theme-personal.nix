{ pkgs, config, stylix,  ... }:

  let
    base16-schemes = pkgs.fetchFromGitHub {
      owner = "tinted-theming";
      repo = "base16-schemes";
      rev = "cf6bc892a24af19e11383adedc6ce7901f133ea7";
      sha256 = "sha256-U9pfie3qABp5sTr3M9ga/jX8C807FeiXlmEZnC4ZM58=";
    };
  in {
    stylix.base16Scheme = "${base16-schemes}/gruvbox-dark-hard.yaml";

    stylix.image = ./backgrounds/9.png;
    # stylix.polarity = "dark";
    # stylix.targets.vim.enable = false;
    stylix.targets.gtk.enable = false;
    # stylix.targets.vscode.enable = false;
    # stylix.targets.rofi.enable = false;

  # wayland.windowManager.sway.config =
  # {
  #   output = {
  #     "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344".bg = "~/.config/backgrounds/rocket.png fit";
  #     "Unknown 0x5A2D 0x00000000".bg = "~/.config/backgrounds/rocket.png fit";
  #   };
  # };

  }
