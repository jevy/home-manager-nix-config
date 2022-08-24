{ config, pkgs, libs, ... }:
{
  imports = [
    ./home.nix
    ./vim/vim.nix
    ./zsh.nix
    ./cli-linux.nix
    ./desktop-linux-personal.nix
    ./mutt-quickjack.nix
    # ./amateur_radio.nix
    ./theme-personal.nix
  ];
}
