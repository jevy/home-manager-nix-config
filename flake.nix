{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    stylix.url = "github:danth/stylix";
    muttdown.url = "github:jevy/muttdown";
    aider.url = "git+https://src.thehellings.com/greg/aider-flake";
  };

  outputs = {
    self,
    home-manager,
    stylix,
    nixpkgs,
    stable,
    muttdown,
    nixos-hardware,
    aider,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    mkSystemConfiguration = system: modules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
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

    macModules = [
      ./home-mac.nix
      ./vim/vim.nix
      ./zsh-clio.nix
      ./zsh.nix
      ./cli-common.nix
      ./desktop-mac.nix
      stylix.homeManagerModules.stylix
      ./theme-mac.nix
      ./taskwarrior-work.nix
      {
        home = {
          username = "jevin";
          homeDirectory = "/Users/jevin";
        };
      }
    ];

    pythonEnv = import ./pythonEnv.nix {inherit pkgs;};

    linuxModules = [
      ({
        config,
        pkgs,
        ...
      }: {nixpkgs.overlays = [stableOverlay];})
      ./nixos/configuration.nix
      ./nixos/hardware-configuration.nix
      ./printers.nix
      stylix.nixosModules.stylix
      ./theme-linux.nix
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
              home.packages = [pythonEnv aider.packages.x86_64-linux.default];
            };
          };
        };
      }
      home-manager.nixosModules.home-manager
    ];
  in {
    nixosConfigurations = {
      x86_64-linux = mkSystemConfiguration "x86_64-linux" linuxModules;
    };
    homeConfigurations = {
      jevin = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        extraSpecialArgs = {inherit inputs;};
        modules = macModules;
      };
    };
  };
}
