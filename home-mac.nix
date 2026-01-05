{ config, pkgs, inputs, ... }:
{
  imports = [
    ./stylix-common.nix
    inputs.spicetify-nix.homeManagerModules.spicetify
  ];

  home.stateVersion = "23.11";
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "jevin";
      email = "jevin@quickjack.ca";
    };
    settings.alias = { st = "status"; };
  };
  programs.difftastic = {
    enable = true;
    git.enable = true;
  };

  home.keyboard = {
    layout = "us";
    variant = "qwerty";
    options = [ "ctrl:nocaps" ];
  };
}
