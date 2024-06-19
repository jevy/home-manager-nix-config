{
  pkgs,
  stylix,
  ...
}: {
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-light-soft.yaml";

  stylix.autoEnable = true;
  stylix.targets.bat.enable = false;
  stylix.targets.vim.enable = false;
}
