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
      programs.neomutt.extraConfig = ''
        set use_threads=threads sort=reverse-last-date sort_aux=date
        set index_format='%4C %Z %<[y?%<[m?%<[d?%[%l:%M%p ]&%[%a %d ]>&%[%b %d ]>&%[%m/%y ]> %-15.15L  %s %g'
        set sidebar_format = "%D%* %n"
      '';
    };
}
