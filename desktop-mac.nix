{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    # spacebar
    # yabai
    # skhd
  ];

  home.file.yabai = {
    executable = true;
    target = ".config/yabai/yabairc";
    text = ''
      #!/usr/bin/env sh

      # load scripting addition
      sudo yabai --load-sa
      # yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"

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

      yabai -m config top_padding    0
      yabai -m config bottom_padding 0
      yabai -m config left_padding   0
      yabai -m config right_padding  0
      yabai -m config window_gap     0

      # rules
      yabai -m rule --add app="^System Preferences$" manage=off

      echo "yabai configuration loaded.."
    '';
  };

  home.file.skhd = {
    target = ".config/skhd/skhdrc";
    text = ''

      -----

      cmd + alt + ctrl - h : yabai -m window --focus west
      cmd + alt + ctrl - l : yabai -m window --focus east
      cmd + alt + ctrl - k : yabai -m window --focus north
      cmd + alt + ctrl - j : yabai -m window --focus south

      hyper - h : yabai -m window --warp west
      hyper - l : yabai -m window --warp east
      hyper - k : yabai -m window --warp north
      hyper - j : yabai -m window --warp south

      hyper - 1 : yabai -m space --focus 1
      hyper - 2 : yabai -m space --focus 2
      hyper - 3 : yabai -m space --focus 3
      hyper - 4 : yabai -m space --focus 4
      hyper - 5 : yabai -m space --focus 5
      hyper - 6 : yabai -m space --focus 6
      hyper - 7 : yabai -m space --focus 7
      hyper - 8 : yabai -m space --focus 8
      hyper - 9 : yabai -m space --focus 9
      hyper - 0 : yabai -m space --focus 0

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

  home.shellAliases = {
    ls = "eza";
    l = "ls -l";
    lt = "ls --tree";
    la = "ls -a";

    fdt = "f() fd $1 -t file -X ls -tr -l);f"; # Search files sort by date

    geoip = "curl ifconfig.co/json";

    rebuildhm = "cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake '.#x86_64-darwin'";

    weather = "${pkgs.curl}/bin/curl https://v2.wttr.in/ottawa";
  };
}
