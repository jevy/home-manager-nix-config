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

      programs.neomutt.extraConfig = lib.mkMerge [
        # Base colors from the active stylix scheme. This reimplements upstream
        # stylix's neomutt target (which simply sources a base16-rendered muttrc
        # via config.lib.stylix.colors); we vendor the template rather than depend
        # on the old mputz86/neomutt stylix fork. mkBefore so the personal
        # `color sidebar_*` overrides below take precedence.
        (lib.mkBefore ''
          set color_directcolor = yes
          source "${config.lib.stylix.colors {
            template = ./base16-stylix.muttrc.mustache;
            extension = ".muttrc";
          }}"
        '')

      # Personal overrides on top of module defaults
      (let
        secretsDir = "${config.sops.defaultSymlinkPath}";
      in ''
        set use_threads=threads sort=reverse-last-date sort_aux=date

        # Esc cancels everywhere — prompts, searches, compose fields.
        # Default is Ctrl+G; remap so behaviour matches the rest of the system.
        set abort_key = "\e"

        # Ctrl+o for reverse-sort prompt (O is taken by lieer sync)
        # Avoiding \e (Alt) prefixes so Esc stays a clean cancel.
        bind index \Co sort-reverse

        # Ctrl+t toggles threaded <-> flat. neomutt has no native toggle for the
        # use_threads enum, so Ctrl+t replays one of two helper macros that each
        # swap which one Ctrl+t points to next (doubled backslashes feed the
        # rebind command as literal text rather than replaying the keys).
        macro index,pager \e1 "<enter-command>set use_threads=threads sort=reverse-last-date sort_aux=date<enter><enter-command>macro index,pager \\Ct \\e2<enter>" "threaded view"
        macro index,pager \e2 "<enter-command>set use_threads=flat sort=reverse-date<enter><enter-command>macro index,pager \\Ct \\e1<enter>" "flat view"
        macro index,pager \Ct \e2 "toggle threaded/flat view"

        # Ctrl+f: notmuch search across all mail (vfolder-from-query). Previously
        # clobbered by the flat-view macro that used to live on this key.
        macro index \Cf "<vfolder-from-query>" "notmuch search"
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
      '')
      ];
    };
}
