{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  # home.username = "jevinhumi";
  # home.homeDirectory = "/home/jevinhumi";

  nixpkgs.config.allowUnfreePredicate = (pkg: true);

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  # home.stateVersion = "21.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "jevin";
    userEmail = "jevin@quickjack.ca";
    aliases = {
      st = "status";
    };
    delta.enable = true;
  };

  home.keyboard = {
    layout = "us";
    variant = "qwerty,colemak-dh";
    options = [ "ctrl:nocaps" "grp:alt_shift_toggle" ];
  };

}
