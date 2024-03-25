{ config, lib, pkgs, muttdown, modulesPath, ... }:

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
    python310Packages.goobook # mutt
    python-with-my-packages
    muttdown.packages.${pkgs.system}.muttdown
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
