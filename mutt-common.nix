{ config, lib, pkgs, modulesPath, ... }:

{
  home.packages = let
    my-python-packages = python-packages: with python-packages; [
      wxPython_4_0
      markdown
      markdown-include
    ];
    python-with-my-packages = pkgs.python3.withPackages my-python-packages;
  in
  with pkgs; [
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
    python310Packages.goobook # mutt
    python-with-my-packages
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
    ".config/mutt/add-html-to-email".source = mutt/add-html-to-email.py;
    ".config/mutt/add-html-to-email".executable = true;
  };
}
