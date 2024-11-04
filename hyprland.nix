{
  config,
  pkgs,
  ...
}: {
  # services.hypridle.enable = true;
  # services.hyprpaper.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
  };
}
