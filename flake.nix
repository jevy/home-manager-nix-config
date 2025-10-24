{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    stylix.url = "github:danth/stylix";
    muttdown.url = "github:jevy/muttdown";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    sops-nix.url = "github:Mic92/sops-nix";
    musnix.url = "github:musnix/musnix";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hy3 = {
      url = "github:outfoxxed/hy3";
      inputs.hyprland.follows = "hyprland";
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
    mcp-servers-nix,
    spicetify-nix,
    hyprland,
    hyprland-plugins,
    hy3,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    mcpConfig = import ./mcp/config.nix {
      unstablePkgsInput = inputs.unstable;
      mcpServersNixInput = inputs.mcp-servers-nix;
      inherit system;
    };

    mkSystemConfiguration = system: modules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          user = "jevin";
        };
        modules = modules;
      };

    # Overlay for Linux
    unstableOverlayLinux = self: super: {
      unstable = import inputs.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-25.9.0"
          "libsoup-2.74.3"
          "qtwebengine-5.15.19"
        ];
        overlays = [
          (final: prev: {
            fluxcd-operator = prev.fluxcd-operator.overrideAttrs (oldAttrs: {
              version = "0.20.0";
              src = prev.fetchFromGitHub {
                owner = "controlplaneio-fluxcd";
                repo = "flux-operator";
                rev = "v0.20.0";
                hash = "sha256-GGHufHUqTylgynK19aaj4KAawlzzuz3iSEHa+vVVPMM=";
              };

              vendorHash = "sha256-5uT/pcfXrinyJ1hXmQ+vmWNuyO33c6d5PAjm6kwOZmY=";

              subPackages = ["cmd/cli" "cmd/mcp"];

              ldflags = [
                "-s"
                "-w"
                "-X main.VERSION=0.20.0"
              ];

              env.CGO_ENABLED = "0";

              doCheck = false;

              postInstall = ''
                # Rename the CLI binary to flux-operator (keeping original behavior)
                mv $out/bin/cli $out/bin/flux-operator
                # Rename the MCP binary to flux-operator-mcp
                mv $out/bin/mcp $out/bin/flux-operator-mcp
              '';

              meta =
                oldAttrs.meta
                // {
                  description = "Kubernetes CRD controller that manages the lifecycle of CNCF Flux CD with MCP server support";
                };
            });
            volsync = prev.buildGoModule rec {
              pname = "volsync";
              version = "latest";
              src = prev.fetchFromGitHub {
                owner = "backube";
                repo = "volsync";
                rev = "ebdf7e9d66c22802ee4d5e24c897041adc17db90";
                sha256 = "sha256-SLYVclFk2BsP9waYQHwNsWtLGt5fSRkIgWdeL8Lp1iA=";
              };
              proxyVendor = true;
              vendorHash = "sha256-AuGRtQ2ItAsgDfF3uCAHQCK2lATMqXChxN8Dr98UmGo=";
              subPackages = ["kubectl-volsync"];
            };
          })
        ];
      };
    };

    # Overlay for macOS (change "aarch64-darwin" to "x86_64-darwin" if you are on Intel)
    unstableOverlayDarwin = self: super: {
      unstable = import inputs.nixpkgs {
        system = "aarch64-darwin";
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-25.9.0"
          "qtwebengine-5.15.19"
        ];
      };
    };

    tailscaleOverlay = self: prev: {
      tailscale = prev.tailscale.overrideAttrs (old: {
        doCheck = false;
      });
    };

    macModules = [
      # Insert the overlay for mac here
      ({
        config,
        pkgs,
        ...
      }: {
        nixpkgs.overlays = [unstableOverlayDarwin tailscaleOverlay];
      })

      ./home-mac.nix
      inputs.sops-nix.homeManagerModules.sops
      ./zsh-spellbook.nix
      ./zsh.nix
      ./cli-common.nix
      ./desktop-mac.nix
      stylix.homeManagerModules.stylix
      ./stylix-common.nix
      ./taskwarrior-work.nix
      inputs.nixvim.homeModules.default
      ./nixvim.nix
      {
        home = {
          username = "jevin";
          homeDirectory = "/Users/jevin";
        };
      }
    ];

    linuxModules = [
      ({
        config,
        pkgs,
        ...
      }: {
        nixpkgs.overlays = [unstableOverlayLinux tailscaleOverlay];
      })

      ./nixos/configuration.nix
      ./nixos/hardware-configuration.nix
      ./printers.nix
      stylix.nixosModules.stylix
      ./stylix-common.nix
      nixos-hardware.nixosModules.framework-12th-gen-intel
      inputs.musnix.nixosModules.musnix
      {
        musnix.enable = true;
        users.users.jevin.extraGroups = [ "audio" ];
      }
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = {
            inherit inputs stylix muttdown hy3;
          };
          users = {
            jevin = {
              imports = [
                ./jevin-linux.nix
                inputs.sops-nix.homeManagerModules.sops
                inputs.nixvim.homeModules.default
                ./nixvim.nix
                (
                  {...}: {
                    # First, create the settings directory
                    home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/.keep".text = "";

                    # Then, place the file inside it
                    home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json".source =
                      mcpConfig;
                  }
                )
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
        pkgs = nixpkgs.legacyPackages.aarch64-darwin; # This is for macOS specific packages
        extraSpecialArgs = {
          inherit inputs;
          # If mcpOutputs were needed for macOS, you'd define and pass a mac-specific version
        };
        modules = macModules;
      };
    };
  };
}
