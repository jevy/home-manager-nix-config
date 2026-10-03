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
      artWallpaper = pkgs.callPackage ../../pkgs/art-wallpaper { };
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
      shellQml = pkgs.replaceVars ../../pkgs/art-wallpaper/shell.qml {
        dir =
          if cfg.strategy == "art-pinned" then "${pinnedDir}" else "${config.xdg.cacheHome}/art-wallpaper";
        serif = config.stylix.fonts.serif.name;
        inherit (colors) base00 base04 base05;
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
      })

      (lib.mkIf (cfg.strategy == "art-rotate") {
        systemd.user.services.art-wallpaper = {
          Unit.Description = "Fetch a new art wallpaper";
          Service = {
            Type = "oneshot";
            ExecStart = "${artWallpaper}/bin/art-wallpaper next";
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
