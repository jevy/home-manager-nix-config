# Mutt email configuration
{ inputs, ... }:
{
  flake.modules.homeManager.mutt =
    { config, lib, pkgs, ... }:
    {
      home.packages = with pkgs; [
        # mutt-wizard
        neomutt # mutt-wizard
        curl # mutt-wizard
        isync # mutt-wizard
        msmtp # mutt-wizard
        pass # mutt-wizard
        gnupg # mutt-wizard
        # pinentry # mutt-wizard
        # notmuch # mutt-wizard
        # lieer # mutt-wizard
        w3m # mutt-wizard
        abook # mutt-wizard
        urlscan # mutt-wizard
        poppler-utils # mutt-wizard
        # python310Packages.goobook # mutt
        inputs.muttdown.packages.${pkgs.stdenv.hostPlatform.system}.muttdown
      ];

      accounts.email = {
        # maildirBasePath = "mail_quickjack";

        accounts.quickjack = {
          # maildir.path = "/";
          primary = true;
          flavor = "gmail.com";
          realName = "Jevin Maltais";
          address = "jevin@quickjack.ca";
          aliases = [ "jevin@buildingremoteteams.com" "jevin@galasathome.com" "jevyjevjevs@gmail.com" ];

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
        ".config/mutt/muttrc".source = ../../mutt/quickjack.muttrc;
        ".config/mutt/colors-gruvbox-shuber.muttrc".source = ../../mutt/colors-gruvbox-shuber.muttrc;
        ".muttdown.yaml".text = "sendmail: gmi send -t -C ~/Maildir/quickjack";
        ".config/mutt/common.muttrc".source = ../../mutt/common.muttrc;
        ".config/mailcap".source = ../../mutt/mailcap;
      };
    };
}
