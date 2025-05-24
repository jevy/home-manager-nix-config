{
  pkgs,
  config,
  ...
}: {
  stylix.enable = true;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-soft.yaml";

  stylix.targets.bat.enable = false;
  stylix.targets.vim.enable = false;
}