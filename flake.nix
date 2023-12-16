{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url                    = "github:nix-community/home-manager/release-23.11";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-23.11";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url                          = "github:danth/stylix";
  };

  outputs = { self, home-manager, stylix, nixpkgs, nixpkgs-unstable, nixos-hardware, ... }@inputs:

    let
      mkSystemConfiguration = system: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = modules;
      };

      unstableOverlay = self: super: {
        unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
          config.permittedInsecurePackages = [
            "electron-25.9.0"
          ];
        };
      };

      linuxModules = [
        ({ config, pkgs, ... }: { nixpkgs.overlays = [ unstableOverlay ]; })
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        ./printers.nix
        stylix.nixosModules.stylix ./theme-personal.nix
        nixos-hardware.nixosModules.framework-12th-gen-intel
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit stylix; };
            users = {
              jevin = {
                imports = [
                  ./jevin-linux.nix
                ];
              };
            };
          };
        }
        home-manager.nixosModules.home-manager
      ];

    in
    {
      nixosConfigurations = {
        x86_64-linux = mkSystemConfiguration "x86_64-linux" linuxModules;
      };
    };
}
