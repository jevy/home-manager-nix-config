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
    nixosConfigurations = {
      # Lenovo has hostname `nixos`
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # pkgs = nixpkgs.legacyPackages.x86_64-linux;
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
        ];
      };
    };

    homeConfigurations =
    let
      system = "x86_64-linux";
      # pkgs = import nixpkgs {
      #   inherit system;
      # };
    in
    {
      "jevin" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        # pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; inherit nix-colors; }; # Pass flake inputs to our config
        modules = [ ./jevin-linux.nix ];
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      };

      "jevinhumi" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; inherit nix-colors; }; # Pass flake inputs to our config
        modules = [ ./work-linux.nix ];
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      };
    };


  };
}
