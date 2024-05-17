{
  pkgs,
  stylix,
  ...
}: let
  base16-schemes = pkgs.fetchFromGitHub {
    owner = "tinted-theming";
    repo = "base16-schemes";
    rev = "cf6bc892a24af19e11383adedc6ce7901f133ea7";
    sha256 = "sha256-U9pfie3qABp5sTr3M9ga/jX8C807FeiXlmEZnC4ZM58=";
  };
in {
  stylix.base16Scheme = "${base16-schemes}/gruvbox-material-dark-soft.yaml";

  stylix.autoEnable = false;
  stylix.targets.tmux.enable = true;
  stylix.targets.fzf.enable = true;
  stylix.targets.bat.enable = true;
  stylix.targets.kitty.enable = true;
}
