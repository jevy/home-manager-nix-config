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
    userName = "jevin";
    userEmail = "jevin@quickjack.ca";
    aliases = { st = "status"; };
    difftastic.enable = true;
  };

  home.keyboard = {
    layout = "us";
    variant = "qwerty";
    options = [ "ctrl:nocaps" ];
  };
}
