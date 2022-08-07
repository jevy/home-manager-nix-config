{
  description = "Jevin's Humi Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url = "github:nix-community/home-manager/release-22.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = inputs@{ home-manager, nix-colors, nixpkgs,... }: {
    nixosConfigurations = {
      hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jevin = import ./jevin-linux.nix;
            home-manager.extraSpecialArgs = { inherit nix-colors; };
            home-manager.stateVersion = "22.05";
          }
        ];
      };
    };
  };
}
