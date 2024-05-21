{
  pkgs,
  stylix,
  ...
}: {
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-light-soft.yaml";

  stylix.autoEnable = false;
  stylix.targets.tmux.enable = true;
  stylix.targets.fzf.enable = true;
  stylix.targets.bat.enable = true;
  stylix.targets.kitty.enable = true;
}
