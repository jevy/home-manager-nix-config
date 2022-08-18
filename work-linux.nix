{ config, pkgs, libs, ... }:
{
  imports = [
    ./home.nix
    ./vim/vim.nix
    ./zsh.nix
    ./cli-common.nix
    ./cli-linux.nix
    ./desktop-linux-work.nix
    ./mutt-humi.nix
    ./theme-work.nix
    ./taskwarrior-work.nix
  ];
}

