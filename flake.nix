{
  description = "Jevin's Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
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
      url = "github:hyprwm/Hyprland/v0.52.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hy3 = {
      url = "github:outfoxxed/hy3/hl0.52.0";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs =
    {
      self,
      home-manager,
      stylix,
      nixpkgs,
      muttdown,
      nixos-hardware,
      sops-nix,
      nixvim,
      mcp-servers-nix,
      spicetify-nix,
      hyprland,
      hy3,
      ...
    }@inputs:
    let
      # ============================================
      # Shared Configuration
      # ============================================

      permittedInsecurePackages = [
        "electron-25.9.0"
        "libsoup-2.74.3"
        "qtwebengine-5.15.19"
      ];

      # Volsync overlay (shared across platforms)
      volsyncOverlay = final: prev: {
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
          subPackages = [ "kubectl-volsync" ];
        };
      };

      tailscaleOverlay = final: prev: {
        tailscale = prev.tailscale.overrideAttrs (old: {
          doCheck = false;
        });
      };

      # ============================================
      # Linux Configuration
      # ============================================

      linuxSystem = "x86_64-linux";

      pkgsLinux = import nixpkgs {
        system = linuxSystem;
        config = {
          allowUnfree = true;
          allowBroken = true;
          segger-jlink.acceptLicense = true;
          inherit permittedInsecurePackages;
        };
        overlays = [
          volsyncOverlay
          tailscaleOverlay
        ];
      };

      mcpConfigVSCode = import ./mcp/config.nix {
        nixpkgsInput = inputs.nixpkgs;
        mcpServersNixInput = inputs.mcp-servers-nix;
        system = linuxSystem;
        flavor = "vscode";
        fileName = "mcp_settings.json";
      };

      mcpConfigClaudeCode = import ./mcp/config.nix {
        nixpkgsInput = inputs.nixpkgs;
        mcpServersNixInput = inputs.mcp-servers-nix;
        system = linuxSystem;
        flavor = "claude";
        fileName = ".mcp.json";
      };

      linuxModules = [
        { nixpkgs.pkgs = pkgsLinux; }

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
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs = {
              inherit
                inputs
                stylix
                muttdown
                hy3
                mcpConfigVSCode
                mcpConfigClaudeCode
                ;
              pkgsWithUnfree = pkgsLinux;
            };
            users.jevin = {
              imports = [
                ./jevin-linux.nix
                inputs.sops-nix.homeManagerModules.sops
                inputs.nixvim.homeModules.default
                ./nixvim.nix
                (
                  { ... }:
                  {
                    # VSCode Cline MCP settings
                    home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/.keep".text = "";
                    home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json".source =
                      mcpConfigVSCode;

                    # Claude Code MCP settings (global config)
                    home.file.".mcp.json".source = mcpConfigClaudeCode;
                  }
                )
              ];
            };
          };
        }
      ];

      # ============================================
      # macOS Configuration
      # ============================================

      darwinSystem = "aarch64-darwin";

      macModules = [
        {
          nixpkgs.overlays = [
            volsyncOverlay
            tailscaleOverlay
          ];
        }
        ./home-mac.nix
        inputs.sops-nix.homeManagerModules.sops
        ./zsh-spellbook.nix
        ./zsh.nix
        ./cli-common.nix
        ./desktop-mac.nix
        stylix.homeModules.stylix
        ./stylix-common.nix
        ./taskwarrior-work.nix
        inputs.nixvim.homeModules.default
        ./nixvim.nix
      ];

    in
    {
      # ============================================
      # Outputs
      # ============================================

      packages.aarch64-darwin = {
        nvim-vscode = nixvim.legacyPackages.aarch64-darwin.makeNixvim (import ./nixvim-vscode.nix);
      };

      nixosConfigurations.x86_64-linux = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = {
          inherit inputs;
          user = "jevin";
        };
        modules = linuxModules;
      };

      homeConfigurations.jevin = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${darwinSystem};
        extraSpecialArgs = {
          inherit inputs;
        };
        modules = macModules;
      };
    };
}