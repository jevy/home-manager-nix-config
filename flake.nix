{
  description = "Jevin's Humi Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url                    = "github:nix-community/home-manager/release-22.11";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-22.11";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    jevy-custom.url                     = "path:/home/jevin/code/personal/jevy-nixpkgs-overlays";
    stylix.url                          = "github:danth/stylix";
  };
  outputs = { home-manager, stylix, nixpkgs, nixpkgs-unstable, nixos-hardware, jevy-custom, ... }@inputs:

    # Modeling it after: https://rycee.gitlab.io/home-manager/index.html#sec-flakes-nixos-module
    let
      system = "x86_64-linux";
      overlay-unstable = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
      custom-packages = jevy-custom.overlay;
    in {
    nixosConfigurations = {

      # Lenovo has hostname `nixos`
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable custom-packages ]; })
          ./nixos/lenovo/configuration.nix
          ./nixos/lenovo/hardware-configuration.nix
          ./printers.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users = {
                jevin     = import ./jevin-linux.nix;
                jevinhumi = import ./work-linux.nix;
              };
            };
          }
        ];
      };

      framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ({ config, pkgs, ... }: {})
          ./nixos/framework/configuration.nix
          ./nixos/framework/hardware-configuration.nix
          ./printers.nix
          stylix.nixosModules.stylix ./theme-personal.nix
          nixos-hardware.nixosModules.framework-12th-gen-intel
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              nixpkgs.overlays = [ overlay-unstable custom-packages ];
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit stylix; };
              users = {
                jevin     = import ./jevin-linux.nix;
                jevinhumi = import ./work-linux.nix;
              };
            };
          }
        ];
      };

    };

  };

}
