{
  description = "Home Manager configuration of Jevy";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    # home-manager.url = "github:nix-community/home-manager/release-22.05";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "/home/jevin/code/personal/home-manager";
    # home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { nixpkgs, home-manager, nix-colors, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      homeConfigurations.jevin = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # nixpkgs.config.allowUnfree = true;

        modules = [
          ./home.nix
          ./vim.nix
          ./zsh.nix
          ./cli-common.nix
          ./cli-linux.nix
          ./desktop-linux-personal.nix
          ./mutt-quickjack.nix
          # ./amateur_radio.nix
          ./theme-personal.nix
          {
            home = {
              username = "jevin";
              homeDirectory = "/home/jevin";
              stateVersion = "22.05";
            };
          }
        ];

        extraSpecialArgs = { inherit nix-colors; };
      };
    };

}
