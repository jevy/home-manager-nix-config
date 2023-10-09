{config, pkgs, ...}: {

  imports =
  [
    ./hyprland-eww.nix
  ];

  home.packages = with pkgs; [
    gtk-layer-shell
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    recommendedEnvironment = true;
    extraConfig = ''
      $mainMod = SUPER
      $mod = SUPER

      bind= $mod, u, exec, firefox
      bind= $mod, c, exec, rofi -show calc
      bind= $mod, t, exec, kitty -- ${pkgs.ranger}/bin/ranger ~/Downloads
      bind = SUPER_SHIFT, Q, killactive,
      bind = $mod, D, exec, rofi -show run
      bind = $mod, return, exec, kitty

      bind = $mainMod, h, movefocus, l
      bind = $mainMod, l, movefocus, r
      bind = $mainMod, k, movefocus, u
      bind = $mainMod, j, movefocus, d

      bind = $mainMod SHIFT, h, movewindow, l
      bind = $mainMod SHIFT, l, movewindow, r
      bind = $mainMod SHIFT, k, movewindow, u
      bind = $mainMod SHIFT, j, movewindow, d

      # Switch workspaces with mainMod + [0-9]
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      exec-once=eww open topbar
      input {
        kb_options=ctrl:nocaps
        follow_mouse = 1
      }
      animations {
          enabled = yes
      }

      monitor=eDP-1,2256x1504@59.99,0x0,1.5
    '';
  };
}
