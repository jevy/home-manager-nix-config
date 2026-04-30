# Mutt email configuration via neomutt-for-gmail
{ inputs, ... }:
{
  flake.modules.homeManager.mutt =
    { config, lib, pkgs, ... }:
    {
      imports = [ inputs.neomutt-gmail.homeManagerModules.default ];

      accounts.email.accounts.quickjack = {
        primary = true;
        flavor = "gmail.com";
        realName = "Jevin Maltais";
        address = "jevin@quickjack.ca";
        aliases = [
          "jevin@buildingremoteteams.com"
          "jevin@galasathome.com"
          "jevyjevjevs@gmail.com"
        ];

      };

      # Personal macros (module provides Gmail + goobook defaults)
      programs.neomutt.macros = [
        { map = ["index" "pager"]; key = "b"; action = "<resend-message>"; }
      ];

      # Wrap neomutt with TERM=xterm-direct so ncurses sees truecolor support
      # (xterm-ghostty terminfo lacks the RGB flag that ncurses needs for hex colors)
      home.shellAliases.neomutt = "TERM=xterm-direct neomutt";

      # Personal overrides on top of module defaults
      programs.neomutt.extraConfig = let
        secretsDir = "${config.sops.defaultSymlinkPath}";
      in ''
        set use_threads=threads sort=reverse-last-date sort_aux=date
        set index_format='%4C %Z %<[y?%<[m?%<[d?%[%l:%M%p ]&%[%a %d ]>&%[%b %d ]>&%[%m/%y ]> %-15.15L  %s %g'
        set sidebar_format = "%D%* %n"

        # Load contacts from sops secrets
        set my_wife_email = `cat ${secretsDir}/wife_email`
        set my_quickbooks_email = `cat ${secretsDir}/quickbooks_email`

        # Virtual folder for Ashley
        virtual-mailboxes "Ashley" "notmuch://?query=from:$my_wife_email or to:$my_wife_email"

        # Forward to QuickBooks receipts (disable mime_forward so body + attachments are inline)
        macro index,pager Q "<enter-command>set mime_forward=no forward_attachments=yes<enter><forward-message>$my_quickbooks_email<enter><enter-command>set mime_forward=yes<enter>"

        # Sidebar: uniform color for all folders, only highlight current/navigating
        color sidebar_new #ddc7a1 #32302f
        color sidebar_flagged #ddc7a1 #32302f
        color sidebar_unread #ddc7a1 #32302f
        color sidebar_highlight #32302f #e78a4e
        color sidebar_indicator bold #e78a4e #32302f
      '';
    };
}
