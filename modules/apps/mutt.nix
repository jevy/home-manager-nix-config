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

      home.packages = [ pkgs.w3m ];

      xdg.configFile."mailcap".text = ''
        text/html; w3m -dump -T text/html -cols 80 -o display_link_number=1; copiousoutput
        application/*; xdg-open %s &; test=test -n "$DISPLAY"
        image/*; xdg-open %s &; test=test -n "$DISPLAY"
        video/*; xdg-open %s &; test=test -n "$DISPLAY"
        audio/*; xdg-open %s &; test=test -n "$DISPLAY"
      '';

      # Personal overrides on top of module defaults
      programs.neomutt.extraConfig =
        builtins.readFile ./gruvbox.neomuttrc
        + ''
          set use_threads=threads sort=reverse-last-date sort_aux=date
          set index_format='%4C %Z %<[y?%<[m?%<[d?%[%l:%M%p ]&%[%a %d ]>&%[%b %d ]>&%[%m/%y ]> %-15.15L  %s %g'
          set sidebar_format = "%D%* %n"
          set mailcap_path = ~/.config/mailcap
          auto_view application/pdf application/vnd.openxmlformats-officedocument.wordprocessingml.document
          alternative_order text/enriched text/html text/plain
        '';
    };
}
