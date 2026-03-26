# ncspot (Spotify TUI client)
{ ... }:
{
  flake.modules.homeManager.ncspot =
    { ... }:
    {
      programs.ncspot = {
        enable = true;
        settings = {
          shuffle = true;
          gapless = true;

          keybindings = {
            # q = back (neomutt style), Shift+q = quit
            "q" = "back";
            "Shift+q" = "quit";

            # Vim half-page scroll
            "Ctrl+d" = "move down 5";
            "Ctrl+u" = "move up 5";

            # Shift+h/l = prev/next track
            "Shift+h" = "previous";
            "Shift+l" = "next";

            # Shift+j/k = reorder queue
            "Shift+j" = "shift down 1";
            "Shift+k" = "shift up 1";

            # p = playpause (more accessible than Shift+p default)
            "p" = "playpause";

            # Number keys for quick screen switching
            "1" = "focus queue";
            "2" = "focus search";
            "3" = "focus library";
          };
        };
      };
    };
}
