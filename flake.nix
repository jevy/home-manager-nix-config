{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url                    = "github:nix-community/home-manager/release-23.05";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-23.05";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url                          = "github:danth/stylix/7bcf3ce6c9e9225e87d4e3b0c2e7d27a39954c02";
  };

  outputs = { self, home-manager, stylix, nixpkgs, nixpkgs-unstable, nixos-hardware, ... }@inputs:

    let
      # Define a function that creates a system configuration
      mkSystemConfiguration = system: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = modules;
      };

      # Define the custom overlay
      custom-overlays = final: prev: {
        unstable = import nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };

      # Define the list of modules used for the Linux system
      linuxModules = [
        ({ config, pkgs, ... }: { nixpkgs.overlays = [ custom-overlays ]; })
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
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
              jevin = import ./jevin-linux.nix;
            };
          };
        }
      ];

      # Define the Home Manager configuration for the Darwin system
      jevinDarwin = {
        # You would replace this with your Darwin-specific Home Manager configuration
        imports = [ ./jevin-darwin.nix ];
        home.username = "jevin";
        home.homeDirectory = "/Users/jevin";
      };

    in
    {
      nixosConfigurations = {
        x86_64-linux = mkSystemConfiguration "x86_64-linux" linuxModules;
      };
      homeConfigurations = {
        jevin-darwin = home-manager.lib.homeManagerConfiguration {
          system = "x86_64-darwin";
          username = "jevin";
          homeDirectory = "/Users/jevin";
          configuration = jevinDarwin;
          extraSpecialArgs = inputs;
        };
      };
    };
}
