{ pkgs, config, stylix, ... }: {

  wayland.windowManager.sway.config =
  {
    output = {
      "Goldstar Company Ltd LG ULTRAGEAR 106NTLE12344".bg = "~/.config/backgrounds/rocket.png fit";
      "Unknown 0x5A2D 0x00000000".bg = "~/.config/backgrounds/rocket.png fit";
    };
  };

}
