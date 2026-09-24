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

      # $mod is defined in modules/desktop/hyprland.nix (Ctrl+Alt+Super).
      # hyprlang variables are global to the parsed config, so it resolves here
      # even though these binds are merged in from another module.
      wayland.windowManager.hyprland.settings.bind = [
        "$mod, V, exec, ${pkgs.cliphist}/bin/cliphist list | rofi -dmenu -p clipboard | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"
        "$mod, period, exec, rofi -modes emoji -show emoji"
      ];
    };
}
