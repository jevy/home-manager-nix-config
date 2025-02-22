{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    stylix.url = "github:danth/stylix/release-24.11";
    muttdown.url = "github:jevy/muttdown";
    sops-nix.url = "github:Mic92/sops-nix";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    home-manager,
    stylix,
    nixpkgs,
    unstable,
    muttdown,
    nixos-hardware,
    sops-nix,
    nixvim,
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

    # Overlay for Linux
    unstableOverlayLinux = self: super: {
      unstable = import inputs.unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-25.9.0"
        ];
      };
    };

    # Overlay for macOS (change "aarch64-darwin" to "x86_64-darwin" if you are on Intel)
    unstableOverlayDarwin = self: super: {
      unstable = import inputs.unstable {
        system = "aarch64-darwin";
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-25.9.0"
        ];
      };
    };

    macModules = [
      # Insert the overlay for mac here
      ({
        config,
        pkgs,
        ...
      }: {
        nixpkgs.overlays = [unstableOverlayDarwin];
      })

      ./home-mac.nix
      inputs.sops-nix.homeManagerModules.sops
      ./zsh-spellbook.nix
      ./zsh.nix
      ./cli-common.nix
      ./desktop-mac.nix
      stylix.homeManagerModules.stylix
      ./theme-mac.nix
      ./taskwarrior-work.nix
      inputs.nixvim.homeManagerModules.nixvim
      ./nixvim.nix
      {
        home = {
          username = "jevin";
          homeDirectory = "/Users/jevin";
        };
      }
    ];

    linuxModules = [
      # Insert the overlay for Linux
      ({
        config,
        pkgs,
        ...
      }: {
        nixpkgs.overlays = [unstableOverlayLinux];
      })

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
                inputs.sops-nix.homeManagerModules.sops
                inputs.nixvim.homeManagerModules.nixvim
                ./nixvim.nix
              ];
            };
          };
        };
      }
      home-manager.nixosModules.home-manager
    ];
  in {
    # Linux system
    nixosConfigurations = {
      x86_64-linux = mkSystemConfiguration "x86_64-linux" linuxModules;
    };

    # macOS Home Manager
    homeConfigurations = {
      jevin = home-manager.lib.homeManagerConfiguration {
        # Switch to x86_64-darwin if you have an Intel Mac
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        extraSpecialArgs = {inherit inputs;};
        modules = macModules;
      };
    };
  };
}
