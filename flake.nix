{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url                    = "github:nix-community/home-manager/release-23.05";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-23.05";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    stylix.url                          = "github:danth/stylix/7bcf3ce6c9e9225e87d4e3b0c2e7d27a39954c02";
    hyprland.url                        = "github:hyprwm/Hyprland/v0.30.0";
    eww.url                             = "github:elkowar/eww/a9a35c1804d72ef92e04ee71555bd9e5a08fa17e";
    rust-overlay.url                    = "github:oxalica/rust-overlay";
  };

  outputs = { self, home-manager, stylix, nixpkgs, nixpkgs-unstable, nixos-hardware, hyprland, eww, rust-overlay, ... }@inputs:

    let
      mkSystemConfiguration = system: modules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = modules;
      };

      linuxModules = [
        ({ config, pkgs, ... }: {
          nixpkgs.overlays = [ rust-overlay.overlays.default ];
          environment.systemPackages = [ pkgs.rust-bin.nightly."2023-07-14".default ];
        })
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
              inherit stylix;
              eww = inputs.eww.packages.x86_64-linux.eww;
            };
            users = {
              jevin = {
                imports = [
                  ./jevin-linux.nix
                  hyprland.homeManagerModules.default
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
