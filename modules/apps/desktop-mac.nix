# macOS desktop configuration (yabai, skhd, hammerspoon, etc.)
{ ... }:
{
  flake.modules.homeManager.desktopMac =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # spacebar
        # yabai
        # skhd
        nerd-font-patcher
        scrcpy
        # direnv comes from homeManager.direnv (programs.direnv), which also
        # installs the zsh hook — a bare package here would not.
        lazygit
        # linear is NOT here: it lives in the host's environment.systemPackages
        # so nix-darwin's mkalias trampoline puts a real copy in
        # /Applications/Nix Apps, which Spotlight indexes. A home.packages entry
        # only ever produced a ~/Applications symlink into /nix that
        # LaunchServices refuses to index — see the mac-work host header.
      ];

      # THE DORMANT yabairc AND skhdrc THAT USED TO LIVE HERE ARE GONE, and
      # they were not harmless. They wrote ~/.config/yabai/yabairc and
      # ~/.config/skhd/skhdrc — the DEFAULT paths both tools read when started
      # without -c — while carrying the retired keymap:
      #
      #   cmd + alt + ctrl - i : yabai -m display --focus 1
      #   cmd + alt + ctrl - h/j/k/l : yabai -m window --focus west/east/north/south
      #
      # modules/desktop/yabai.nix now owns both files through services.yabai and
      # services.skhd, which pass explicit -c paths into the Nix store. So these
      # were shadowed rather than active — but they are exactly the bindings you
      # would blame for "$mod+I focuses a display instead of centring the
      # layout", and they sat one missing -c flag away from being live. That is
      # too sharp an edge to leave lying in a dormant module.
      #
      # The yabairc also began with `sudo yabai --load-sa`, which is the
      # scripting-addition load that requires SIP to be partially disabled.
      # modules/desktop/yabai.nix deliberately does not use the scripting
      # addition; see its header for the audit of what actually needs SIP off.
      #
      # The keymap itself is not lost: yabai.nix ports it, and its header records
      # which bindings could not be carried over and why.

      home.file.hammerspoon = {
        executable = false;
        target = ".hammerspoon/init.lua";
        text = ''
          hs.hotkey.bind({}, "F19", function()
            hs.spotify.volumeDown()
          end)
          hs.hotkey.bind({}, "F20", function()
            hs.spotify.volumeUp()
          end)

          spaces = require("hs.spaces")

          -- Enable me to change spaces and move windows to them
          local workspaces = {1, 2, 3, 4, 5, 6, 7, 8, 9}
          for i, v in ipairs(workspaces) do
                  hs.hotkey.bind({"cmd", "alt", "ctrl"}, tostring(i), function()
                    spaces.gotoSpace(spaces.spacesForScreen(primaryScreen())[i])
                  end)

                  hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, tostring(i), function()
                    spaces.moveWindowToSpace(hs.window.focusedWindow(), spaces.spacesForScreen(primaryScreen())[i])
                  end)
          end

          function primaryScreen()
            return desktopWithMostSpaces()
          end

          function isDocked()
              local set = spaces.allSpaces()
              local count = 0
              for key, value in pairs(set) do
                  count = count + 1
                  -- One or two because I have my portable monitor
                  -- Three is at home
                  if count > 2 then
                      return true
                  end
              end
              return false
          end

          function desktopWithMostSpaces()
            local spacesTable = spaces.allSpaces()
            local maxCount = 0
            local maxUuid = nil

            for uuid, values in pairs(spacesTable) do
              local count = #values
              if count > maxCount then
                maxCount = count
                maxUuid = uuid
              end
            end

            return maxUuid
          end
        '';
      };

      home.shellAliases = {
        l = "ls -l";
        lt = "ls --tree";
        la = "ls -a";

        fdt = "f() fd $1 -t file -X ls -tr -l);f"; # Search files sort by date

        geoip = "curl ifconfig.co/json";

        weather = "${pkgs.curl}/bin/curl https://v2.wttr.in/ottawa";
      };
    };
}
