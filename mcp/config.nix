# Simple MCP configuration using mcp-servers-nix framework
{
  unstablePkgsInput,
  mcpServersNixInput,
  system ? "x86_64-linux",
}: let
  # Single pkgs instance with mcp-servers-nix overlay
  pkgs = import unstablePkgsInput {
    inherit system;
    config.allowUnfree = true;
    overlays = [mcpServersNixInput.overlays.default];
  };

  # Kubernetes MCP server wrapper
  kubernetesWrapper = pkgs.runCommand "run-mcp-kubernetes" {
    buildInputs = [pkgs.makeWrapper];
  } ''
    mkdir -p $out/bin
    makeWrapper ${pkgs.lib.getExe' pkgs.nodejs "npx"} $out/bin/run-mcp-kubernetes \
      --add-flags "-y" \
      --add-flags "mcp-server-kubernetes" \
      --prefix PATH : ${pkgs.nodejs}/bin
  '';

in
  # Just generate the configuration file
  mcpServersNixInput.lib.mkConfig pkgs {
    programs = {
      # fetch.enable = true;  # Disabled due to build issues
      context7.enable = true;
      time.enable = true;
      git.enable = true;
      nixos.enable = true;
      serena.enable = true;
    };
    flavor = "claude";
    fileName = "mcp_settings.json";
    settings = {
      servers = {
        "mcp-server-kubernetes" = {
          command = "${kubernetesWrapper}/bin/run-mcp-kubernetes";
          args = ["--verbose"];
        };
      };
    };
  }
