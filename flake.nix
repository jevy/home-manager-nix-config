{
  description = "Jevin's Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url                    = "github:nix-community/home-manager/release-23.05";
    nixpkgs.url                         = "github:NixOS/nixpkgs/nixos-23.05";
    nixos-hardware.url                  = "github:NixOS/nixos-hardware";
    nixpkgs-unstable.url                = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    muttdown.url                        = "path:./custom_packages/muttdown/";
    stylix.url                          = "github:danth/stylix";
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      custom-overlays = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in {
      homeConfigurations.jevin = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
	   ({ config, pkgs, ... }: { nixpkgs.overlays = [ custom-overlays ]; })
           ./home.nix
           ./vim/vim.nix
           ./zsh.nix
           ./cli-common.nix
           ./taskwarrior-work.nix
           ./desktop-mac.nix
	   {
		   home = {
		     username = "jevin";
		     homeDirectory = "/Users/jevin";
		   };
	   }
        ];
      };
    };
}
