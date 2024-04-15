{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    stable.url = "github:NixOS/nixpkgs/nixos-23.11";
    stylix.url = "github:danth/stylix/master";
    muttdown.url = "github:jevy/muttdown";
  };

  outputs = { self, home-manager, stylix, nixpkgs, stable, muttdown, nixos-hardware, ... }@inputs:

    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      mkSystemConfiguration = system: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = modules;
      };

      stableOverlay = self: super: {
        unstable = import inputs.stable {
          system = "x86_64-linux";
          config.allowUnfree = true;
          config.permittedInsecurePackages = [
            "electron-25.9.0"
          ];
        };
      };

      pythonEnv = import ./pythonEnv.nix { inherit pkgs; };

      linuxModules = [
        ({ config, pkgs, ... }: { nixpkgs.overlays = [ stableOverlay ]; })
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        ./printers.nix
        stylix.nixosModules.stylix ./theme-personal.nix
        nixos-hardware.nixosModules.framework-12th-gen-intel
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit stylix muttdown;
            };
            users = {
              jevin = {
                imports = [
                  ./jevin-linux.nix
                ];
                home.packages = [ pythonEnv ];
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
