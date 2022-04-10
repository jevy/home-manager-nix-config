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
    mailcap
    python38Packages.goobook # mutt
    python38Full
    python38Packages.wxPython_4_0
  ];

  accounts.email = 
  { 
    maildirBasePath = "mail_quickjack";

    accounts.mail_quickjack = {
      primary = true;
      flavor = "gmail.com";
      realName = "Jevin Maltais";
      address = "jevin@quickjack.ca";
      aliases = [ "jevin@buildingremoteteams.com" "jevin@galasathome.com" "jevyjevjevs@gmail.com" ];

      maildir.path = "mail";
      notmuch.enable = true;
      lieer = 
        {
          enable = true;
          notmuchSetupWarning = false;
          sync.enable = true;
          settings.drop_non_existing_labels = true;
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

  programs.lieer = {
    enable = true;
  };


  home.file = {
    ".config/mutt/muttrc".source = mutt/muttrc;
  };

}
