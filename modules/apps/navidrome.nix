# Navidrome clients — three to try side by side, all keyboard-driven:
#   ratune      TUI, vim hjkl by default, rodio audio, album art + FFT visualizer
#   ferrosonic  TUI, vim j/k, mpv backend, bit-perfect audio + cava visualizer
#   supersonic  GUI (Fyne), Ctrl+[1-7] nav — log in via its own UI on first run
#
# The two TUIs read server URL + username + password from a TOML config. The
# password comes from the sops secret `navidrome_password`; the whole config is
# rendered by sops-nix at activation (mode 0400, so it never lands in the
# world-readable Nix store). Server + username are not secret.
{ ... }:
let
  server = "https://navidrome.jevy.org";
  username = "jevin";
in
{
  flake.modules.homeManager.navidrome =
    { config, pkgs, ... }:
    {
      home.packages = [
        (pkgs.callPackage ../../pkgs/ratune.nix { })
        (pkgs.callPackage ../../pkgs/ferrosonic.nix { })
        pkgs.supersonic
      ];

      # ratune: ~/.config/ratune/config.toml — vim keybinds are the default.
      sops.templates."ratune-config" = {
        path = "${config.home.homeDirectory}/.config/ratune/config.toml";
        content = ''
          [server]
          url = "${server}"
          username = "${username}"
          password = "${config.sops.placeholder.navidrome_password}"

          [library]
          # `f` opens the fuzzy picker; fzf is bundled on the wrapper's PATH.
          fuzzy = true
        '';
      };

      # ferrosonic: ~/.config/ferrosonic/config.toml — server page is F6, but we
      # template it here so it connects on first launch. Cava visualizer on.
      sops.templates."ferrosonic-config" = {
        path = "${config.home.homeDirectory}/.config/ferrosonic/config.toml";
        content = ''
          BaseURL = "${server}"
          Username = "${username}"
          Password = "${config.sops.placeholder.navidrome_password}"
          Theme = "Catppuccin"
          Cava = true
          CavaSize = 40
          Notifications = true
          Scrobble = true
          SaveQueue = true
        '';
      };
    };
}
