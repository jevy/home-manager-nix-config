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

  accounts.email.accounts.mail_quickjack = 
  {
    primary = true;
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
        settings = ''
          {
              "replace_slash_with_dot": false,
              "account": "jevin@quickjack.ca",
              "timeout": 600,
              "drop_non_existing_label": true,
              "ignore_empty_history": false,
              "ignore_tags": [],
              "ignore_remote_labels": [
                  "important"
              ],
              "remove_local_messages": true,
              "file_extension": ""
          }
        '';
      };
    };

  programs.notmuch = {
    enable = true;
    # new.ignore = [ "/.*[.](json|lock|bak)$/" ];
    new.tags = [];
    search.excludeTags = [ "deleted" "spam" ];
  };


  home.file = {
    ".config/mutt/muttrc".source = mutt/muttrc;
  };

}
