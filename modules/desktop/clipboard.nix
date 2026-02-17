# Clipboard management and rofi launcher
{ ... }:
{
  flake.modules.homeManager.clipboard =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.wl-clipboard ];

      programs.rofi = {
        enable = true;
        plugins = [
          pkgs.rofi-emoji
          pkgs.rofi-calc
          pkgs.rofi-power-menu
        ];
      };

      services.cliphist.enable = true;

      wayland.windowManager.hyprland.settings.bind = [
        "SUPER, V, exec, ${pkgs.cliphist}/bin/cliphist list | rofi -dmenu -p clipboard | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"
        "SUPER, period, exec, rofi -modes emoji -show emoji"
      ];
    };
}
