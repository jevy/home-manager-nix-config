# Mako notification daemon
# Colors, fonts, and opacity are auto-injected by Stylix.
# This module only sets geometric/behavioral properties.
{ ... }:
{
  flake.modules.homeManager.mako =
    { ... }:
    {
      services.mako = {
        enable = true;
        settings = {
          border-radius = 12;
          border-size = 2;
          padding = "14";
          margin = "10";
          width = 350;
          default-timeout = 8000;
          max-icon-size = 64;
          layer = "overlay";

          # Frigate camera notifications: larger icons and wider
          "app-name=frigate" = {
            max-icon-size = 256;
            width = 400;
          };

          # Suppress noisy apps
          "app-name=Spotify".invisible = 1;
          "app-name=Slack".invisible = 1;
          "app-name=Obsidian".invisible = 1;
          "app-name=cloud-drive-ui".invisible = 1;
        };
      };
    };
}
