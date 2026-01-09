{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
    enableZshIntegration = true;
    systemd.enable = pkgs.stdenv.isLinux;
    installVimSyntax = true;
    settings = {
      shell-integration-features = "sudo,ssh-env,ssh-terminfo";
      font-family = "MesloLGS Nerd Font";
      font-size = 11;
      keybind =
        [
          "ctrl+,=unbind"
          "ctrl+a>c=new_tab"
          "ctrl+a>ctrl+c=new_tab"
          "ctrl+h=goto_split:left"
          "ctrl+l=goto_split:right"
          "ctrl+a>h=new_split:left"
          "ctrl+a>ctrl+h=new_split:left"
          "ctrl+a>l=new_split:right"
          "ctrl+a>ctrl+l=new_split:right"
          "ctrl+a>f=toggle_split_zoom"
          "ctrl+a>ctrl+f=toggle_split_zoom"
          "ctrl+a>n=next_tab"
          "ctrl+a>ctrl+n=next_tab"
          "ctrl+a>p=previous_tab"
          "ctrl+a>ctrl+p=previous_tab"
        ]
        ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
          "super+a>c=new_tab"
          "super+a>ctrl+c=new_tab"
          "super+h=goto_split:left"
          "super+l=goto_split:right"
          "super+a>h=new_split:left"
          "super+a>ctrl+h=new_split:left"
          "super+a>l=new_split:right"
          "super+a>ctrl+l=new_split:right"
          "super+a>f=toggle_split_zoom"
          "super+a>ctrl+f=toggle_split_zoom"
          "super+a>n=next_tab"
          "super+a>ctrl+n=next_tab"
          "super+a>p=previous_tab"
          "super+a>ctrl+p=previous_tab"
        ]);
    };
  };
}

