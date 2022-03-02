{
  description = "Home Manager configuration of Jevy";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    home-manager.url = "github:nix-community/home-manager/release-21.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    duplicity_script.url = "/home/jevin/code/personal/duplicity_script";
  };

  outputs = { home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "jevin";
    in {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        # Specify the path to your home configuration here
        configuration = import ./home.nix;

        inherit system username;
        homeDirectory = "/home/${username}";
        # Update the state version as needed.
        # See the changelog here:
        # https://nix-community.github.io/home-manager/release-notes.html#sec-release-21.05
        stateVersion = "21.11";

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };
}
