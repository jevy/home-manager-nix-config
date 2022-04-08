{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    mutt-wizard
    neomutt # mutt-wizard
    curl # mutt-wizard
    isync # mutt-wizard
    msmtp # mutt-wizard
    pass # mutt-wizard
    gnupg # mutt-wizard
    pinentry # mutt-wizard
    notmuch # mutt-wizard
    lieer # mutt-wizard
    w3m # mutt-wizard
    abook # mutt-wizard
    urlscan # mutt-wizard
    poppler_utils # mutt-wizard
    mailcap
    python38Packages.goobook # mutt
    python38Full
    python38Packages.wxPython_4_0
  ];

  home.file = {
    ".config/mutt/muttrc".source = mutt/muttrc;
  };

}
