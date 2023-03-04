{
  description = "Jevin's Humi Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url                    = "github:nix-community/home-manager/release-22.11";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-22.11";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    muttdown.url                        = "path:./custom_packages/muttdown/";
    stylix.url                          = "github:danth/stylix";
  };
  outputs = { home-manager, stylix, nixpkgs, nixpkgs-unstable, nixos-hardware, muttdown, ... }@inputs:

    # Modeling it after: https://rycee.gitlab.io/home-manager/index.html#sec-flakes-nixos-module
    let
      system = "x86_64-linux";
      custom-overlays = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
        pkgs-with-custom-pkgs = import nixpkgs {
          inherit system;
          overlays = [ muttdown.overlay ];
        };
      };
    in {
    nixosConfigurations = {

      # Lenovo has hostname `nixos`
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs muttdown; }; # Pass flake inputs to our config
        modules = [
          ({ config, pkgs, ... }: { nixpkgs.overlays = [ custom-overlays ]; })
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
        specialArgs = { inherit inputs muttdown; }; # Pass flake inputs to our config
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
                jevinhumi = import ./work-linux.nix;
              };
            };
          }
        ];
      };

    };

  };

}
