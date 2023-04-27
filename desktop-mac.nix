{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    # spacebar
    # yabai # Installed using home brew for easier start/stop
    # skhd
    nerd-font-patcher
    exa
    neovide
  ];

  home.file.yabai = {
    executable = true;
    target = ".config/yabai/yabairc";
    text = ''
      #!/usr/bin/env sh

      # load scripting addition
      yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
      sudo yabai --load-sa

      yabai -m config layout bsp
      yabai -m config mouse_follows_focus          off
      yabai -m config focus_follows_mouse          off
      yabai -m config window_origin_display        default
      yabai -m config window_placement             second_child
      yabai -m config window_topmost               off
      yabai -m config window_shadow                on
      yabai -m config window_opacity               off
      yabai -m config window_opacity_duration      0.0
      yabai -m config active_window_opacity        1.0
      yabai -m config normal_window_opacity        0.90
      yabai -m config window_border                off
      yabai -m config window_border_width          6
      yabai -m config active_window_border_color   0xff775759
      yabai -m config normal_window_border_color   0xff555555
      yabai -m config insert_feedback_color        0xffd75f5f
      yabai -m config split_ratio                  0.50
      yabai -m config auto_balance                 off
      yabai -m config mouse_modifier               fn
      yabai -m config mouse_action1                move
      yabai -m config mouse_action2                resize
      yabai -m config mouse_drop_action            swap
      yabai -m config focus_follows_mouse	   autoraise
      yabai -m config mouse_follows_focus	   on

      yabai -m config top_padding    0
      yabai -m config bottom_padding 0
      yabai -m config left_padding   0
      yabai -m config right_padding  0
      yabai -m config window_gap     0

      # rules
      yabai -m rule --add app="^System Preferences$" manage=off

      yabai -m signal -add event=window_destroyed action="yabai -m window --focus first"

      echo "yabai configuration loaded.."
    '';
  };

  home.file.skhd = {
    target = ".config/skhd/skhdrc";
    text = ''
      cmd + alt + ctrl - h : yabai -m window --focus west
      cmd + alt + ctrl - l : yabai -m window --focus east
      cmd + alt + ctrl - k : yabai -m window --focus north
      cmd + alt + ctrl - j : yabai -m window --focus south

      hyper - h : yabai -m window --warp west
      hyper - l : yabai -m window --warp east
      hyper - k : yabai -m window --warp north
      hyper - j : yabai -m window --warp south

      # Turned off in favor for Hammerspoon as it doesn't need disabling of MacOS security
      # Move windows to workspaces and move there
      # cmd + alt + ctrl - 1 : yabai -m space --focus 1
      # hyper - 1 : yabai -m window --space 1
      # cmd + alt + ctrl - 2 : yabai -m space --focus 2
      # hyper - 2 : yabai -m window --space 2
      # cmd + alt + ctrl - 3 : yabai -m space --focus 3
      # hyper - 3 : yabai -m window --space 3
      # cmd + alt + ctrl - 4 : yabai -m space --focus 4
      # hyper - 4 : yabai -m window --space 4
      # cmd + alt + ctrl - 5 : yabai -m space --focus 5
      # hyper - 5 : yabai -m window --space 5
      # cmd + alt + ctrl - 6 : yabai -m space --focus 6
      # hyper - 6 : yabai -m window --space 6
      # cmd + alt + ctrl - 7 : yabai -m space --focus 7
      # hyper - 7 : yabai -m window --space 7
      # cmd + alt + ctrl - 8 : yabai -m space --focus 8
      # hyper - 8 : yabai -m window --space 8
      # cmd + alt + ctrl - 9 : yabai -m space --focus 9
      # hyper - 9 : yabai -m window --space 9
      # cmd + alt + ctrl - 0 : yabai -m space --focus 0
      # hyper - 0 : yabai -m window --space 0

      cmd + alt + ctrl - i : yabai -m display --focus 1 # Top monitor
      hyper - i            : yabai -m window --display 1; yabai -m display --focus 1
      cmd + alt + ctrl - o : yabai -m display --focus 2 # Side monitor
      hyper - o            : yabai -m window --display 2; yabai -m display --focus 2
      cmd + alt + ctrl - u : yabai -m display --focus 3 # Bottom monitor
      hyper - u            : yabai -m window --display 3; yabai -m display --focus 3

      alt - e : yabai -m window --toggle split

      cmd + alt + ctrl - t : yabai -m window --toggle float;\
                             yabai -m window --grid 4:4:1:1:2:2
    '';
  };

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
      local workspaces = {1, 2, 3, 4, 5}
      for i, v in ipairs(workspaces) do
              hs.hotkey.bind({"cmd", "alt", "ctrl"}, tostring(i), function()
                spaces.gotoSpace(spaces.spacesForScreen(primaryScreen())[i])
              end)

              hs.hotkey.bind({"cmd", "alt", "ctrl", "shift"}, tostring(i), function()
                spaces.moveWindowToSpace(hs.window.focusedWindow(), spaces.spacesForScreen(primaryScreen())[i])
              end)
      end

      function primaryScreen()
          if isDocked() then
            return "C4DABF08-CACF-41A2-B565-96F6F0832374"
          else
            return "37D8832A-2D66-02CA-B9F7-8F30A301B230"
          end
      end

      function isDocked()
          local set = spaces.allSpaces()
          local count = 0
          for key, value in pairs(set) do
              count = count + 1
              if count > 1 then
                  return true
              end
          end
          return false
      end
    '';
  };
}
