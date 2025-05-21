{
  description = "MCP Server Configuration Flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mcp-servers-nix.url = "github:natsukium/mcp-servers-nix";
  };
  outputs = {
    self,
    nixpkgs,
    mcp-servers-nix,
    ...
  } @ inputs: let
    system = "x86_64-linux";

    # This pkgs instance *includes* the mcp-servers-nix overlay,
    # making pkgs.mcp-server-time etc. available.
    # inputs.nixpkgs for this mcp/flake.nix is 'unstable' due to `follows` in the main flake.
    pkgs_for_mcp_executables = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true; # Assuming this is still desired
      overlays = [ mcp-servers-nix.overlays.default ];
    };

    # This pkgs instance is plain (no mcp-servers-nix overlay),
    # as per the mcp-servers-nix documentation example for mkConfig.
    pkgs_for_mkconfig = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

  in {
    packages = {
      "${system}" = {
        # The executables:
        default = pkgs_for_mcp_executables.buildEnv {
          name = "mcp-server-executables";
          paths = [
            pkgs_for_mcp_executables.mcp-server-time
            pkgs_for_mcp_executables.mcp-server-fetch
            pkgs_for_mcp_executables.mcp-server-git
          ];
        };

        # The JSON config path:
        generatedMcpConfig = mcp-servers-nix.lib.mkConfig pkgs_for_mkconfig {
          programs = {
            time.enable = true;
            fetch.enable = true;
            git.enable = true;
            # TODO add
            # Obsidian
            # Kubernetes
            # NixOS
          };
          flavor = "vscode";
          fileName = "generated_mcp_config.json"; # Explicitly set the filename
        };
      };
    };
  };
}

