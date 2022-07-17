{ config, pkgs, libs, ... }:
{

  imports =
  [
    ./desktop-linux-common.nix
  ];

  home.file = {
    ".config/polybar-scripts/task_polybar.sh".source = waybar/polybar/task_polybar.sh;
  };

  # For Flakpak
  xdg.systemDirs.data = [
    "/home/jevinhumi/.local/share/flatpak/exports/share"
  ];

  xdg.mimeApps.defaultApplications =
  {
    "x-scheme-handler/http"  = [ "google-chrome.desktop"];
    "x-scheme-handler/https" = [ "google-chrome.desktop"];
    "text/html"              = [ "google-chrome.desktop"];
  };

}
