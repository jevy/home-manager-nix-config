{
  description = "Jevin's Humi Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url                    = "github:nix-community/home-manager/release-22.05";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-22.05";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-colors.url                      = "github:misterio77/nix-colors";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ home-manager, nix-colors, nixpkgs, nixos-hardware, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      lib = nixpkgs.lib;
    in {
      nixosConfigurations = {
        jevin = lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            ./hardware-configuration.nix
            nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
            home-manager.nixosModules.home-manager {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jevin = {
                imports = [ ./jevin-linux.nix ];
              };
              home-manager.extraSpecialArgs = { inherit nix-colors; };
            }
          ];
        };
        jevinhumi = lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            ./hardware-configuration.nix
            nixos-hardware.nixosModules.lenovo-thinkpad-x1-7th-gen
            home-manager.nixosModules.home-manager {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.jevin = {
                imports = [
                  ./home.nix
                  ./vim/vim.nix
                  ./zsh.nix
                  ./cli-common.nix
                  ./cli-linux.nix
                  ./desktop-linux-work.nix
                  ./mutt-humi.nix
                  ./theme-work.nix
                  ./taskwarrior-work.nix
                ];
              };
              home-manager.extraSpecialArgs = { inherit nix-colors; };
            }
          ];
        };
      };
  };
}
