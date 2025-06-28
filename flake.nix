{
  description = "Jevin's Home Manager configuration";

  inputs = {
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    stylix.url = "github:danth/stylix/release-25.05";
    muttdown.url = "github:jevy/muttdown";
    spicetify-nix.url = "github:Gerg-L/spicetify-nix/24.11";
    sops-nix.url = "github:Mic92/sops-nix";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "unstable";
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
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    generateMcpOutputs = import ./mcp/config.nix;

    mcpOutputs = generateMcpOutputs {
      unstablePkgsInput = inputs.unstable;
      mcpServersNixInput = inputs.mcp-servers-nix;
      inherit system;
      user = "jevin";
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
      unstable = import inputs.unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "electron-25.9.0"
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
          })
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
      ./stylix-common.nix
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
      ./stylix-common.nix
      nixos-hardware.nixosModules.framework-12th-gen-intel
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";
          extraSpecialArgs = {
            inherit inputs stylix muttdown;
          };
          users = {
            jevin = {
              imports = [
                ./jevin-linux.nix
                inputs.sops-nix.homeManagerModules.sops
                inputs.nixvim.homeManagerModules.nixvim
                ./nixvim.nix
                          (
                            {...}: {
                              home.packages = [
                                mcpOutputs.default
                              ];
          
                              # First, create the settings directory
                              home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/.keep".text = "";
          
                              # Then, place the file inside it
                              home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json".source =
                                mcpOutputs.generatedMcpConfig;
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

