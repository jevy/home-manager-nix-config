{
  description = "Home Manager configuration of Jevy";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url = "github:nix-community/home-manager/release-22.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = inputs@{ home-manager, nix-colors, nixpkgs-unstable,... }: {

      packages.x86_64-linux.homeConfigurations.jevin = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration =  { pkgs, ... }:
          let
            overlay-unstable = final: prev: {
              unstable = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
            };
          in
          {
            nixpkgs.overlays = [ overlay-unstable ];
            nixpkgs.config.allowUnfree = true;
            imports = [
              ./home.nix
              ./vim/vim.nix
              ./zsh.nix
              ./cli-common.nix
              ./cli-linux.nix
              ./desktop-linux-personal.nix
              ./mutt-quickjack.nix
              # ./amateur_radio.nix
              ./theme-personal.nix
            ];
          };

        extraSpecialArgs = { inherit nix-colors; };
        system = "x86_64-linux";
        username = "jevin";
        homeDirectory = "/home/jevin";
        stateVersion = "22.05";
      };

      packages.x86_64-linux.homeConfigurations.jevinhumi = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration =  { pkgs, ... }:
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
           ./taskwarrior.nix
          ];
        };

        extraSpecialArgs = { inherit nix-colors; };
        system = "x86_64-linux";
        username = "jevinhumi";
        homeDirectory = "/home/jevinhumi";
        stateVersion = "22.05";
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
