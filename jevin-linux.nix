{
  config,
  pkgs,
  libs,
  inputs,
  ...
}: {
  imports = [
    ./home.nix
    #./vim/vim.nix
    ./zsh.nix
    ./cli-linux.nix
    ./desktop-linux-personal.nix
    ./stylix-common.nix
    ./mutt-quickjack.nix
    # ./amateur_radio.nix
    # ./theme-personal.nix
    # ./hyprland.nix
    ./sway.nix
    ./music-making.nix
  ];

}

