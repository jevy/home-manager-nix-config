# Font configuration for NixOS
{ ... }:
{
  flake.modules.nixos.fonts =
    { pkgs, ... }:
    {
      fonts = {
        packages = with pkgs; [
          dejavu_fonts
          freefont_ttf
          gyre-fonts
          unifont
          nerd-fonts.meslo-lg
          nerd-fonts.symbols-only
          weather-icons
          font-awesome
          noto-fonts-color-emoji
        ];

        fontconfig = {
          defaultFonts = {
            serif = [ "DejaVu Serif" ];
            sansSerif = [ "DejaVu Sans" ];
            monospace = [
              "MesloLGS Nerd Font"
              "Symbols Nerd Font"
              "Weather Icons"
              "DejaVu Sans Mono"
            ];
            emoji = [
              "Noto Color Emoji"
              "Symbols Nerd Font"
              "Weather Icons"
              "Font Awesome 5 Free"
            ];
          };

          antialias = true;
          subpixel = {
            rgba = "none";
            lcdfilter = "none";
          };
        };
      };
    };
}
