{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    unstable.eww-wayland
    socat
  ];

  xdg.configFile."eww/eww.scss" = {
    text = ''
      * {
        all: unset; //Unsets everything so you can style everything from scratch
      }

      //Global Styles
      .bar {
        background-color: #3a3a3a;
        color: #b0b4bc;
        padding: 10px;
      }

      // Styles on classes (see eww.yuck for more information)

      .sidestuff slider {
        all: unset;
        color: #ffd5cd;
      }

      .metric scale trough highlight {
        all: unset;
        background-color: #D35D6E;
        color: #000000;
        border-radius: 10px;
      }
      .metric scale trough {
        all: unset;
        background-color: #4e4e4e;
        border-radius: 50px;
        min-height: 3px;
        min-width: 50px;
        margin-left: 10px;
        margin-right: 20px;
      }
      .metric scale trough highlight {
        all: unset;
        background-color: #D35D6E;
        color: #000000;
        border-radius: 10px;
      }
      .metric scale trough {
        all: unset;
        background-color: #4e4e4e;
        border-radius: 50px;
        min-height: 3px;
        min-width: 50px;
        margin-left: 10px;
        margin-right: 20px;
      }
      .label-ram {
        font-size: large;
      }
      .workspaces button:hover {
        color: #D35D6E;
      }
      '';
  };
  xdg.configFile."eww/eww.yuck" = {
    text = ''

    (deflisten workspaces :initial "[]" "bash ~/.config/eww/scripts/get-workspaces")
    (deflisten current_workspace :initial "1" "bash ~/.config/eww/scripts/get-active-workspace")
    (defwidget workspaces []
      (eventbox :onscroll "bash ~/.config/eww/scripts/change-active-workspace {} ''${current_workspace}" :class "workspaces-widget"
        (box :space-evenly true
          (label :text "''${workspaces}''${current_workspace}" :visible false)
          (for workspace in workspaces
            (eventbox :onclick "hyprctl dispatch workspace ''${workspace.id}"
              (box :class "workspace-entry ''${workspace.id == current_workspace ? "current" : ""} ''${workspace.windows > 0 ? "occupied" : "empty"}"
                (label :text "''${workspace.id}")
                )
              )
            )
          )
        )
      )

    (defpoll time :interval "1s"
      "date '+%I:%M %p %e %B %Y'")

    (defwidget sidestuff []
    (box :class "sidestuff" :orientation "h" :space-evenly false :halign "end"
      time))

    (defwidget music []
      (box :class "music"
           :orientation "h"
           :space-evenly false
           :halign "center"
        "Music placeholder"))

    (defwidget bar []
      (centerbox :orientation "h"
        (workspaces)
        (music)
        (sidestuff)))

    (defwindow topbar
               :monitor 0
               :geometry (geometry :x "0%"
                                   :y "0%"
                                   :width "90%"
                                   :height "10px"
                                   :anchor "top center")
               :stacking "fg"
               :windowtype "dock"
               :exclusive true
               :focusable false
    (bar))

    '';
  };
  xdg.configFile."eww/scripts/change-active-workspace" = {
    executable = true;
    text = ''
      #! /usr/bin/env bash
      function clamp {
              min=$1
              max=$2
              val=$3
              python -c "print(max($min, min($val, $max)))"
      }

      direction=$1
      current=$2
      if test "$direction" = "down"
      then
              target=$(clamp 1 10 $(($current+1)))
              echo "jumping to $target"
              hyprctl dispatch workspace $target
      elif test "$direction" = "up"
      then
              target=$(clamp 1 10 $(($current-1)))
              echo "jumping to $target"
              hyprctl dispatch workspace $target
      fi
    '';
  };
  xdg.configFile."eww/scripts/get-active-workspace" = {
    executable = true;
    text = ''
      #! /usr/bin/env bash
      hyprctl monitors -j | jq '.[] | select(.focused) | .activeWorkspace.id'

      socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - |
        stdbuf -o0 awk -F '>>|,' -e '/^workspace>>/ {print $2}' -e '/^focusedmon>>/ {print $3}'
    '';
  };
  xdg.configFile."eww/scripts/get-workspaces" = {
    executable = true;
    text = ''
      #! /usr/bin/env bash

      spaces (){
              WORKSPACE_WINDOWS=$(hyprctl workspaces -j | jq 'map({key: .id | tostring, value: .windows}) | from_entries')
              seq 1 10 | jq --argjson windows "''${WORKSPACE_WINDOWS}" --slurp -Mc 'map(tostring) | map({id: ., windows: ($windows[.]//0)})'
      }

      spaces
      socat -u UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
              spaces
      done
    '';
  };
}
