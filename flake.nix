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
  outputs = { home-manager, nix-colors, nixpkgs, nixpkgs-unstable, nixos-hardware, ... }@inputs: {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    # Modeling it after: https://rycee.gitlab.io/home-manager/index.html#sec-flakes-nixos-module
    nixosConfigurations = {

      # Lenovo has hostname `nixos`
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
          home-manager.nixosModules.home-manager
          {
            home-manager.users.jevin = {
              imports = [ ./jevin-linux.nix ];
            };
          }
          {
            home-manager.users.jevinhumi = {
              imports = [ ./work-linux.nix ];
            };
          }
        ];
        home-manager.extraSpecialArgs = { inherit nix-colors; };
      };

      # Other laptop goes here. Either Linux or Mac

    };

  };
}
