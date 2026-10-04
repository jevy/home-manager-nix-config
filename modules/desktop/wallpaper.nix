# Wallpaper, with a per-host strategy (set `wallpaper.strategy` in the host):
#
#   static      hyprpaper shows stylix.image (the lowpoly gruvbox render).
#   art-rotate  quickshell shows a random CC0 painting with a title/artist/year
#               caption; a timer (wallpaper.art.schedule) or $mod SHIFT A runs
#               `art-wallpaper next`, which writes ~/.cache/art-wallpaper and
#               quickshell crossfades to it. Theme stays gruvbox.
#   art-pinned  quickshell shows the painting in pkgs/art-wallpaper/pinned.json
#               (written by `art-wallpaper pin`), fetched at build time, and it
#               becomes stylix.image, so hyprlock uses it too. With
#               wallpaper.art.themeFromArt, stylix also generates the colour
#               scheme from it instead of using gruvbox.
#
# Theme mode (art strategies + Noctalia): Meta+D → c, or `theme-mode toggle`,
# switches the live desktop between stylix's gruvbox and gruvbox tinted by the
# painting on screen (pkgs/gruvbox-art, strength 0.6). No rebuild: it reaches
# only Noctalia, Hyprland borders and ghostty. GTK is light Adwaita on purpose
# (desktop/apps.nix) and Qt/Kvantum and nvim keep build-time gruvbox.
# `noctalia msg color-scheme-set` persists a [theme] table into Noctalia's
# settings.toml (the CONFIG DRIFT file in noctalia.nix), so once toggled that
# file, not config.toml, picks the palette. Gruvbox mode writes the same
# values Nix does, but a future Nix theme change needs that table deleted.
#
# The art strategies replace hyprpaper with quickshell, so stylix's hyprpaper
# target is off for them. Black shows until a painting loads.
#
# The option lives on the NixOS side because art-pinned changes stylix.image
# and base16Scheme, which home-manager's stylix follows from the system. The
# home-manager half reads it back through osConfig.
{ ... }:
{
  flake.modules.nixos.wallpaper =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.wallpaper;
      pin = lib.importJSON ../../pkgs/art-wallpaper/pinned.json;
    in
    {
      options.wallpaper = {
        strategy = lib.mkOption {
          type = lib.types.enum [
            "static"
            "art-rotate"
            "art-pinned"
          ];
          default = "static";
          description = "How the desktop wallpaper is chosen and drawn. See modules/desktop/wallpaper.nix.";
        };
        art.schedule = lib.mkOption {
          type = lib.types.str;
          default = "daily";
          description = "systemd OnCalendar for a new painting under art-rotate.";
        };
        art.themeFromArt = lib.mkEnableOption "generating the stylix colour scheme from the pinned painting (art-pinned only)";
        art.pinnedImage = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = pkgs.fetchurl {
            name = "art-wallpaper-${toString pin.id}.jpg";
            url = pin.image;
            inherit (pin) hash;
          };
          description = "The pinned painting, fetched from pinned.json.";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf (cfg.strategy != "static") {
          # The caption bubble's type (pkgs/art-wallpaper/shell.qml).
          fonts.packages = with pkgs; [
            cormorant
            source-serif
            inter
          ];
        })
        (lib.mkIf (cfg.strategy == "art-pinned") {
          stylix.image = cfg.art.pinnedImage;
        })
        (lib.mkIf (cfg.strategy == "art-pinned" && cfg.art.themeFromArt) {
          stylix.base16Scheme = config.stylix.generated.palette;
          stylix.polarity = "dark";
        })
        {
          assertions = [
            {
              assertion = cfg.art.themeFromArt -> cfg.strategy == "art-pinned";
              message = "wallpaper.art.themeFromArt needs wallpaper.strategy = \"art-pinned\"; a rotating painting can't feed a build-time theme.";
            }
          ];
        }
      ];
    };

  flake.modules.homeManager.wallpaper =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      cfg = osConfig.wallpaper;
      isArt = cfg.strategy != "static";
      artWallpaper = pkgs.callPackage ../../pkgs/art-wallpaper {
        openrouterKeyFile = config.sops.secrets.openrouter_api_key.path;
      };
      pin = lib.importJSON ../../pkgs/art-wallpaper/pinned.json;

      # Same layout the script writes: <id>.jpg + current.json naming it.
      pinnedDir = pkgs.linkFarm "art-wallpaper-pinned" [
        {
          name = "${toString pin.id}.jpg";
          path = cfg.art.pinnedImage;
        }
        {
          name = "current.json";
          path = pkgs.writeText "current.json" (
            builtins.toJSON (
              removeAttrs pin [ "hash" ]
              // {
                file = "${toString pin.id}.jpg";
              }
            )
          );
        }
      ];

      inherit (config.lib.stylix) colors;

      artDir =
        if cfg.strategy == "art-pinned" then "${pinnedDir}" else "${config.xdg.cacheHome}/art-wallpaper";

      # theme-mode needs Noctalia for its palette switch.
      themeMode = pkgs.callPackage ../../pkgs/gruvbox-art/theme-mode.nix {
        inherit artDir;
        hyprland = config.wayland.windowManager.hyprland.finalPackage;
        noctalia = config.programs.noctalia.package;
        gruvboxScheme = pkgs.writeText "stylix-scheme.yaml" (
          lib.concatMapStrings (n: "${n}: \"${colors.${n}}\"\n") (
            map (i: "base0${i}") (lib.stringToCharacters "0123456789ABCDEF")
          )
        );
      };
      hasThemeMode = isArt && (config.desktopShell or null) == "noctalia";

      shellQml = pkgs.replaceVars ../../pkgs/art-wallpaper/shell.qml {
        dir = artDir;
        inherit (colors)
          base00
          base03
          base04
          base05
          base06
          base0B
          ;
      };
    in
    lib.mkMerge [
      (lib.mkIf isArt {
        stylix.targets.hyprland.hyprpaper.enable = false;

        # art-wallpaper info/open/pin work under both art strategies.
        home.packages = [ artWallpaper ];

        programs.quickshell = {
          enable = true;
          configs.art-wallpaper = pkgs.linkFarm "art-wallpaper-quickshell" [
            {
              name = "shell.qml";
              path = shellQml;
            }
          ];
          activeConfig = "art-wallpaper";
          systemd.enable = true;
        };

        # Qt refuses to decode an image needing more than 256 MB, which full
        # scans pass from ~8200x8200 up (9727x7430 = 289 MB failed, leaving
        # the zoom blurry). Largest seen so far is ~460 MB.
        systemd.user.services.quickshell.Service.Environment = [ "QT_IMAGEIO_MAXALLOC=1024" ];
      })

      # Live gruvbox ⇄ painting-tinted theme (Meta+D → c). See the header.
      (lib.mkIf hasThemeMode {
        home.packages = [ themeMode ];

        # Empty in gruvbox mode; "?" makes a missing file fine. Loaded after
        # the stylix theme, so its colours win.
        programs.ghostty.settings.config-file = "?${config.xdg.stateHome}/theme-mode/ghostty";

        # Hyprland's keywords reset on restart; Noctalia's choice persists in
        # its settings.toml but the palette file may predate a new painting.
        systemd.user.services.theme-mode = {
          Unit = {
            Description = "Re-apply the gruvbox/art theme mode";
            After = [
              "graphical-session.target"
              "noctalia.service"
            ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe themeMode} refresh";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })

      (lib.mkIf (hasThemeMode && cfg.strategy == "art-rotate") {
        # A new painting re-tints when art mode is on (no-op in gruvbox mode).
        systemd.user.services.art-wallpaper.Service.ExecStartPost = "${lib.getExe themeMode} refresh";
      })

      (lib.mkIf (cfg.strategy == "art-rotate") {
        # Persistent=true runs a missed midnight fetch the instant the laptop
        # wakes, before wifi is back (2026-10-04: DNS failed 4s before the
        # AP associated). network-online.target can't help: it's a system
        # unit, invisible to the user manager, and is reached once at boot,
        # not on resume. nm-online blocks until NetworkManager is connected;
        # the restart covers "connected" arriving before DNS, or a museum
        # API outage.
        systemd.user.services.art-wallpaper = {
          Unit = {
            Description = "Fetch a new art wallpaper";
            StartLimitIntervalSec = 600;
            StartLimitBurst = 5;
          };
          Service = {
            Type = "oneshot";
            ExecStartPre = "${pkgs.networkmanager}/bin/nm-online -q --timeout=90";
            ExecStart = "${artWallpaper}/bin/art-wallpaper next";
            Restart = "on-failure";
            RestartSec = 30;
          };
        };

        systemd.user.timers.art-wallpaper = {
          Unit.Description = "New art wallpaper (${cfg.art.schedule})";
          Timer = {
            OnCalendar = cfg.art.schedule;
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };

        wayland.windowManager.hyprland.settings.bind = [
          "$mod SHIFT, A, exec, systemctl --user start art-wallpaper.service"
        ];
      })
    ];
}
