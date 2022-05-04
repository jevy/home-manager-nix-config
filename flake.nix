{
  description = "Home Manager configuration of Jevy";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url = "github:nix-community/home-manager/release-21.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { home-manager, ... }: {

      packages.x86_64-linux.homeConfigurations.jevin = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration =  { pkgs, ... }:
        {
          imports = [
            ./home.nix
            ./vim.nix
            ./zsh.nix
            ./cli-common.nix
            ./cli-linux.nix
            ./desktop-linux.nix
            ./mutt.nix
            ./amateur_radio.nix
          ];
        };

        system = "x86_64-linux";
        username = "jevin";
        homeDirectory = "/home/jevin";
        stateVersion = "21.11";
      };

      packages.x86_64-linux.homeConfigurations.jevinhumi = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration =  { pkgs, ... }:
        {
          imports = [
           ./home.nix
           ./vim.nix
           ./zsh.nix
           ./cli-common.nix
           ./cli-linux.nix
           ./desktop-linux-work.nix
           ./mutt-humi.nix
          ];
        };

        system = "x86_64-linux";
        username = "jevinhumi";
        homeDirectory = "/home/jevinhumi";
        stateVersion = "21.11";
      };

      packages.aarch64-darwin.homeConfigurations.jevin = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration =  { pkgs, ... }:
        {
          imports = [
           ./home.nix
           ./vim.nix
           ./zsh.nix
           ./cli-common.nix
           ./desktop-mac.nix
           # ./mutt-humi.nix # No darwin for lieer
          ];
        };

        system = "aarch64-darwin";
        username = "jevin";
        homeDirectory = "/Users/jevin";
        stateVersion = "21.11";
      };
    };
}
