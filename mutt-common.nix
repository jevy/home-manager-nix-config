{ config, lib, pkgs, modulesPath, ... }:

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
    ".config/mutt/common.muttrc".source = mutt/common.muttrc;
    ".config/mailcap".source = mutt/mailcap;
  };
}
