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
      "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344".bg = "~/.config/backgrounds/rocket.png fit";
      "Unknown 0x5A2D 0x00000000".bg = "~/.config/backgrounds/rocket.png fit";
    };

    # fonts = [ "MesloLGS NF" ];
    colors = {
      background      = "#${config.colorscheme.colors.base00}";
      focused         = { background = "#${config.colorscheme.colors.base05}"; border = "#${config.colorscheme.colors.base05}"; text = "#${config.colorscheme.colors.base00}"; indicator = "#${config.colorscheme.colors.base00}"; childBorder =  "#${config.colorscheme.colors.base05}";};
      unfocused       = { background = "#${config.colorscheme.colors.base01}"; border = "#${config.colorscheme.colors.base01}"; text = "#${config.colorscheme.colors.base00}"; indicator = "#${config.colorscheme.colors.base00}"; childBorder =  "#${config.colorscheme.colors.base01}";};
      # focusedInactive = { background = "#${config.colorscheme.colors.base04}"; border = "#${config.colorscheme.colors.base04}"; text = "#${config.colorscheme.colors.base00}"; };
      # urgent          = { background = "#${config.colorscheme.colors.base02}"; border = "#${config.colorscheme.colors.base02}"; text = "#${config.colorscheme.colors.base00}"; };
    };
  };

}
