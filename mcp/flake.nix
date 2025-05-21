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
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    packages.${system}.default = mcp-servers-nix.lib.mkConfig pkgs {
      programs = {
        time.enable = true;
      };
    };
  };
}
