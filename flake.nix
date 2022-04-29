{
  description = "Home Manager configuration of Jevy";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url = "github:nix-community/home-manager/release-21.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { home-manager, ... }:
  let
    system = "x86_64-linux";
  in {
    homeConfigurations = {
      jevin = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration =  { pkgs, ... }:
        {
          imports = [
            ./home.nix
            ./vim.nix
            ./zsh.nix
            ./cli.nix
            ./desktop-linux.nix
            ./mutt.nix
            ./amateur_radio.nix
            ./desktop-linux-work.nix
            #./mutt.nix
            #./amateur_radio.nix
          ];
        };

        inherit system;
        username = "jevin";
        homeDirectory = "/home/jevin";
        stateVersion = "21.11";
      };

      jevinhumi = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration =  { pkgs, ... }:
        {
          imports = [
           ./home.nix
           ./vim.nix
           ./zsh.nix
           ./cli.nix
           ./desktop-linux-work.nix
           ./mutt-humi.nix
          ];
        };

        inherit system;
        username = "jevinhumi";
        homeDirectory = "/home/jevinhumi";
        stateVersion = "21.11";
      };
    };
  };
}
