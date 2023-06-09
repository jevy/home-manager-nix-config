{
  description = "Jevin's Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url                    = "github:nix-community/home-manager/release-23.05";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-23.05";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # muttdown.url                        = "path:./custom_packages/muttdown/";
    stylix.url                          = "github:danth/stylix/master";
  };
  outputs = { home-manager, stylix, nixpkgs, nixpkgs-unstable, nixos-hardware, ... }@inputs:

    # Modeling it after: https://rycee.gitlab.io/home-manager/index.html#sec-flakes-nixos-module
    let
      system = "x86_64-linux";
      custom-overlays = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in {
    nixosConfigurations = {

      framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ custom-overlays ]; })
          ./nixos/framework/configuration.nix
          ./nixos/framework/hardware-configuration.nix
          ./printers.nix
          stylix.nixosModules.stylix ./theme-personal.nix
          nixos-hardware.nixosModules.framework-12th-gen-intel
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit stylix; };
              users = {
                jevin     = import ./jevin-linux.nix;
              };
            };
          }
        ];
      };

    };

  };

}
