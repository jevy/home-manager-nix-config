{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    # mutt-wizard
    neomutt # mutt-wizard
    curl # mutt-wizard
    isync # mutt-wizard
    msmtp # mutt-wizard
    pass # mutt-wizard
    gnupg # mutt-wizard
    pinentry # mutt-wizard
    # notmuch # mutt-wizard
    # lieer # mutt-wizard
    w3m # mutt-wizard
    abook # mutt-wizard
    urlscan # mutt-wizard
    poppler_utils # mutt-wizard
    python38Packages.goobook # mutt
    python38Full
    python38Packages.wxPython_4_0
  ];

  accounts.email = 
  { 

    accounts.humi = {
      # maildir.path = "/";
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

  programs.notmuch = {
    enable = true;
    # new.ignore = [ "/.*[.](json|lock|bak)$/" ];
    new.tags = [];
    search.excludeTags = [ "deleted" "spam" ];
    maildir.synchronizeFlags = false;
  };

  services.lieer.enable = true;
  programs.lieer.enable = true;

  home.file = {
    ".config/mutt/muttrc".source = mutt/humi.muttrc;
    ".config/mutt/common.muttrc".source = mutt/common.muttrc;
  };

}
