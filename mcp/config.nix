# Simple MCP configuration using mcp-servers-nix framework
{
  nixpkgsInput,
  mcpServersNixInput,
  system ? "x86_64-linux",
  flavor ? "claude",
  fileName ? "mcp_settings.json",
}:
let
  # Single pkgs instance with mcp-servers-nix overlay
  pkgs = import nixpkgsInput {
    inherit system;
    config.allowUnfree = true;
    overlays = [ mcpServersNixInput.overlays.default ];
  };

  # Container-use MCP server (containerized environments for coding agents)
  containerUse = pkgs.callPackage ../pkgs/container-use.nix { };

  # Kubernetes MCP server wrapper
  kubernetesWrapper =
    pkgs.runCommand "run-mcp-kubernetes"
      {
        buildInputs = [ pkgs.makeWrapper ];
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.lib.getExe' pkgs.nodejs "npx"} $out/bin/run-mcp-kubernetes \
          --add-flags "-y" \
          --add-flags "mcp-server-kubernetes" \
          --prefix PATH : ${pkgs.nodejs}/bin
      '';

  # Grafana MCP server (build from source with Go 1.24)
  grafanaMcpServer = pkgs.buildGo124Module rec {
    pname = "mcp-grafana";
    version = "0.7.10";

    src = pkgs.fetchFromGitHub {
      owner = "grafana";
      repo = "mcp-grafana";
      rev = "v${version}";
      hash = "sha256-DDkIWCJneL7l59CThzPkHzcB/lcUZrcVDZO/nWsZ2ss=";
    };

    vendorHash = "sha256-4dOsXrwUk+muYLIec9hBdMl/W3lk/pMvliEWeYrU5zQ=";

    subPackages = [ "cmd/mcp-grafana" ];

    meta = {
      description = "Model Context Protocol server for Grafana";
      homepage = "https://github.com/grafana/mcp-grafana";
      mainProgram = "mcp-grafana";
    };
  };

  # Wrapper that reads token from sops secret at runtime
  # The secret path matches what sops-nix creates in home.nix
  grafanaMcpWrapper = pkgs.writeShellApplication {
    name = "run-grafana-mcp";
    runtimeInputs = [ grafanaMcpServer ];
    text = ''
      # Read token from sops secret file (created by sops-nix in home.nix)
      # sops-nix for home-manager puts secrets at ~/.config/sops-nix/secrets/
      SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
      if [ -f "$SOPS_SECRET_PATH/grafana_homelab_secret" ]; then
        GRAFANA_SERVICE_ACCOUNT_TOKEN=$(cat "$SOPS_SECRET_PATH/grafana_homelab_secret")
        export GRAFANA_SERVICE_ACCOUNT_TOKEN
      fi
      exec mcp-grafana "$@"
    '';
  };

  # n8n MCP server wrapper (reads API key from sops secret)
  n8nMcpWrapper = pkgs.writeShellApplication {
    name = "run-n8n-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      # Read API key from sops secret file
      SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
      if [ -f "$SOPS_SECRET_PATH/n8n_api_key" ]; then
        N8N_API_KEY=$(cat "$SOPS_SECRET_PATH/n8n_api_key")
        export N8N_API_KEY
      fi
      exec npx n8n-mcp "$@"
    '';
  };
in
# Just generate the configuration file
mcpServersNixInput.lib.mkConfig pkgs {
  programs = {
    context7.enable = true;
    time.enable = true;
    git.enable = true;
    # nixos.enable = true; # Disabled: fastmcp version conflict with mcp 1.25.0 (needs <1.17.0)
    playwright.enable = true;
  };
  inherit flavor fileName;
  settings = {
    servers = {
      "mcp-server-kubernetes" = {
        command = "${kubernetesWrapper}/bin/run-mcp-kubernetes";
        args = [ "--verbose" ];
      };
      "grafana" = {
        command = "${grafanaMcpWrapper}/bin/run-grafana-mcp";
        args = [ "--disable-write" ];
        env = {
          GRAFANA_URL = "https://grafana.jevy.org";
          # Token is read from sops secret at runtime by the wrapper
        };
      };
      "container-use" = {
        command = "${containerUse}/bin/container-use";
        args = [ "stdio" ];
      };
      "n8n" = {
        command = "${n8nMcpWrapper}/bin/run-n8n-mcp";
        env = {
          MCP_MODE = "stdio";
          N8N_API_URL = "https://n8n.jevy.org";
          LOG_LEVEL = "error";
          DISABLE_CONSOLE_OUTPUT = "true";
          # API key is read from sops secret at runtime by the wrapper
        };
      };
    };
  };
}
