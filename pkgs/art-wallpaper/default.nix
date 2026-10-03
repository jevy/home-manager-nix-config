{
  pkgs,
  # Secret file holding the OpenRouter API key, for the commentary. Empty
  # (or unreadable at run time) means no commentary, just the museum text.
  openrouterKeyFile ? "",
}:

pkgs.writeShellApplication {
  name = "art-wallpaper";
  runtimeInputs = with pkgs; [
    curl
    jq
    coreutils
    findutils
    gawk
    xdg-utils
    vips
    imagemagick
  ];
  text = builtins.replaceStrings [ "@keyfile@" ] [ openrouterKeyFile ] (
    builtins.readFile ./art-wallpaper.sh
  );
}
