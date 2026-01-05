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
      keybind = [
        "ctrl+a>c=new_tab"
        "ctrl+h=goto_split:left"
        "ctrl+l=goto_split:right"
        "ctrl+a>h=new_split:left"
        "ctrl+a>l=new_split:right"
        "ctrl+a>f=toggle_split_zoom"
        "ctrl+a>n=next_tab"
        "ctrl+a>p=previous_tab"
      ];
    };
  };
}

