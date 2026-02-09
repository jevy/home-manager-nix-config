# Ashell status bar for Hyprland
{ ... }:
{
  flake.modules.homeManager.ashell =
    { ... }:
    {
      programs.ashell = {
        enable = true;
        systemd.enable = true;
        systemd.target = "hyprland-session.target";
        settings = {
          modules = {
            left = [ "Workspaces" ];
            center = [ ];
            right = [
              "CustomWeather"
              "MediaPlayer"
              "Tray"
              [
                "Clock"
                "Volume"
                "Privacy"
                "Settings"
              ]
            ];
          };
          clock = {
            format = "%a %d %b %l:%M %p";
          };
          CustomModule = [
            {
              name = "CustomWeather";
              icon = "";
              command = "wget -O - http://wttr.in/.png?m&format=v2 | feh - -Z";
              listen_cmd = "/home/jevin/.config/nixpkgs/waybar/polybar/ashell-weather.sh";
            }
          ];
          workspaces = {
            visibility_mode = "MonitorSpecificExclusive";
            enable_workspace_filling = false;
          };
        };
      };

      systemd.user.services.ashell = {
        Unit = {
          BindsTo = [ "hyprland-session.target" ];
          PartOf = [
            "hyprland-session.target"
            "graphical-session.target"
          ];
          After = [ "hyprland-session.target" ];
        };
        Service = {
          RestartSec = "2s";
        };
      };
    };
}
