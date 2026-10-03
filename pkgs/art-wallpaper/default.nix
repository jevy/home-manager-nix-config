{ pkgs }:

pkgs.writeShellApplication {
  name = "art-wallpaper";
  runtimeInputs = with pkgs; [
    curl
    jq
    coreutils
    findutils
    xdg-utils
    vips
    imagemagick
  ];
  text = builtins.readFile ./art-wallpaper.sh;
}
