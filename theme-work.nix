{ pkgs, config, nix-colors, ... }: {
  imports = [
    nix-colors.homeManagerModule
  ];

  colorscheme = nix-colors.colorSchemes.gruvbox-dark-medium;

  programs = {
    kitty = {
      # font.name = "MesloLGS NF";
      settings = {
        foreground = "#${config.colorscheme.colors.base05}";
        background = "#${config.colorscheme.colors.base00}";
      };
    };
  };

  wayland.windowManager.sway.config =
  {
    output = {
      "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344".bg = "~/.config/backgrounds/stationeleven.jpg fit";
      "Unknown 0x5A2D 0x00000000".bg = "~/.config/backgrounds/stationeleven.jpg fit";
    };
  };
}
