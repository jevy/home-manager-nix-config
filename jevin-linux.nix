{ config, pkgs, libs, ... }:
{
  imports = [
    ./home.nix
    ./vim/vim.nix
    ./zsh.nix
    ./cli-linux.nix
    ./desktop-linux-personal.nix
    ./mutt-quickjack.nix
    ./vscode.nix
    # ./amateur_radio.nix
    ./theme-personal.nix
    # ./hyprland.nix
    ./sway.nix
    ./music-making.nix
  ];
}
