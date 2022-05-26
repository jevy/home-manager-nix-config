{ pkgs, config, nix-colors, ... }: {
  imports = [
    nix-colors.homeManagerModule
  ];

  colorscheme = nix-colors.colorSchemes.gruvbox-dark-medium;

  programs = {
    kitty = {
      font.name = "MesloLGS NF";
      settings = {
        foreground = "#${config.colorscheme.colors.base05}";
        background = "#${config.colorscheme.colors.base00}";
      };
    };
  };

  wayland.windowManager.sway.config = 
  { 
    fonts = [ "MesloLGS NF" ];
    colors = {
      background = "#${config.colorscheme.colors.base00}";
      focused = "#${config.colorscheme.colors.base05}";
      focusedInactive = "#${config.colorscheme.colors.base04}";
      unfocused = "#${config.colorscheme.colors.base01}";
      urgent = "#${config.colorscheme.colors.base02}";
    };
  };

}
