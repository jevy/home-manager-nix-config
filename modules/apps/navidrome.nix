# Navidrome clients — all keyboard-driven:
#   ferrosonic  TUI, vim j/k, mpv backend, bit-perfect audio + cava visualizer
#   ratune      TUI, vim hjkl by default, rodio audio, album art + FFT visualizer
#   supersonic  GUI (Fyne), Ctrl+[1-7] nav — log in via its own UI on first run
#   feishin     GUI (Electron), mpv backend — log in via its own UI on first run
#
# Platform split: ferrosonic runs everywhere; ratune/supersonic are Linux-only
# here (untested on darwin) and feishin is added on darwin, where a GUI client
# is the natural pairing for the TUI. See pkgs/ferrosonic.nix for what degrades
# on macOS (MPRIS media keys, PipeWire rate switching, cava visualizer).
#
# The TUIs read server URL + username + password from a TOML config. The
# password comes from the sops secret `navidrome_password`; the whole config is
# rendered by sops-nix at activation (mode 0400, so it never lands in the
# world-readable Nix store). Server + username are not secret. The GUI clients
# have no config file to template — log in through their own UI once.
{ ... }:
let
  server = "https://navidrome.jevy.org";
  username = "jevin";
in
{
  flake.modules.homeManager.navidrome =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
      configHome =
        if isLinux then
          "${config.home.homeDirectory}/.config"
        else
          "${config.home.homeDirectory}/Library/Application Support";
    in
    {
      home.packages = [
        (pkgs.callPackage ../../pkgs/ferrosonic.nix { })
      ]
      ++ lib.optionals isLinux [
        (pkgs.callPackage ../../pkgs/ratune.nix { })
        pkgs.supersonic
      ]
      ++ lib.optionals isDarwin [
        pkgs.feishin
      ];

      sops.templates = {
        # ferrosonic: config.toml under the platform's config dir — the server
        # page is F6, but we template it here so it connects on first launch.
        # ferrosonic resolves the directory with the `dirs` crate: XDG on Linux,
        # ~/Library/Application Support on macOS.
        "ferrosonic-config" = {
          path = "${configHome}/ferrosonic/config.toml";
          content = ''
            BaseURL = "${server}"
            Username = "${username}"
            Password = "${config.sops.placeholder.navidrome_password}"
            Theme = "Catppuccin"
            # cava is only on the wrapper's PATH on Linux; ferrosonic probes for
            # it at startup, so asking for it on macOS would just render empty.
            Cava = ${lib.boolToString isLinux}
            CavaSize = 40
            Notifications = true
            Scrobble = true
            SaveQueue = true
          '';
        };
      }
      // lib.optionalAttrs isLinux {
        # ratune: ~/.config/ratune/config.toml — vim keybinds are the default.
        "ratune-config" = {
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
      };
    };
}
