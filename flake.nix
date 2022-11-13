{
  description = "Jevin's Humi Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url                    = "github:nix-community/home-manager/release-22.05";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-22.05";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-colors.url                      = "github:misterio77/nix-colors";
  };
  outputs = { home-manager, nix-colors, nixpkgs, nixpkgs-unstable, nixos-hardware, ... }@inputs:

    # Modeling it after: https://rycee.gitlab.io/home-manager/index.html#sec-flakes-nixos-module
    let
      system = "x86_64-linux";
      overlay-unstable = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in {
    nixosConfigurations = {

      # Lenovo has hostname `nixos`
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })
          ./configuration.nix
          ./hardware-configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit nix-colors; };
              users = {
                jevin     = import ./jevin-linux.nix;
                jevinhumi = import ./work-linux.nix;
              };
            };
          }
        ];
      };

      # Other laptop goes here. Either Linux or Mac

    };

  };

}
