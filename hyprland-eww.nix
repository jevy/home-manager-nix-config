{ config, pkgs, eww, ... }:

{
  home.packages = with pkgs; [ eww ];

  xdg.configFile."eww.yuck" = {
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
