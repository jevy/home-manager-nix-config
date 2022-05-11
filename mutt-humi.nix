{ config, pkgs, libs, ... }:
{
  imports = 
  [
    ./mutt-common.nix 
  ]; 

  accounts.email = 
  { 

    accounts.humi = {
      primary = true;
      flavor = "gmail.com";
      realName = "Jevin Maltais";
      address = "jevin.maltais@humi.ca";

      # maildir.path = "mail";
      notmuch.enable = true;
      lieer = 
        {
          enable = true;
          sync.enable = true;
          settings.drop_non_existing_label = true;
          settings.ignore_remote_labels = ["important"];
        };
      };
    };

  home.file = {
    ".config/mutt/muttrc".source = mutt/humi.muttrc;
  };

}
