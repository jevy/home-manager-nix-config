# MCP (Model Context Protocol) server configuration
# Uses programs.mcp as the single source of truth for all MCP server configs
{ inputs, ... }:
{
  flake.modules.homeManager.mcp =
    { config, pkgs, lib, ... }:
    let
      # Kubernetes MCP server wrapper.
      #
      # INTERIM: still launched via npx, but with --prefer-offline. Without it,
      # npx does an npm-registry version check on every launch that took >30s
      # under concurrent MCP startup and tripped Claude Code's 30s timeout;
      # --prefer-offline skips that check and starts in ~0.7s from the warm cache.
      #
      # TODO(native): upstream is a Bun project shipping only bun.lockb (no npm
      # lockfile), so it can't use buildNpmPackage. The native path is bun2nix —
      # see pkgs/mcp-server-kubernetes/README.md for the one-time bun.nix
      # generation, then swap this wrapper for the compiled binary.
      kubernetesWrapper =
        pkgs.runCommand "run-mcp-kubernetes"
          {
            buildInputs = [ pkgs.makeWrapper ];
          }
          ''
            mkdir -p $out/bin
            makeWrapper ${lib.getExe' pkgs.nodejs "npx"} $out/bin/run-mcp-kubernetes \
              --add-flags "--prefer-offline" \
              --add-flags "-y" \
              --add-flags "mcp-server-kubernetes" \
              --prefix PATH : ${pkgs.nodejs}/bin
          '';

      # Grafana MCP server (build from source with Go 1.25)
      grafanaMcpServer = pkgs.buildGo125Module rec {
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
      grafanaMcpWrapper = pkgs.writeShellApplication {
        name = "run-grafana-mcp";
        runtimeInputs = [ grafanaMcpServer ];
        text = ''
          SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
          if [ -f "$SOPS_SECRET_PATH/grafana_homelab_secret" ]; then
            GRAFANA_SERVICE_ACCOUNT_TOKEN=$(cat "$SOPS_SECRET_PATH/grafana_homelab_secret")
            export GRAFANA_SERVICE_ACCOUNT_TOKEN
          fi
          exec mcp-grafana "$@"
        '';
      };

      # TrueNAS MCP server (build from source — upstream ships no nixpkgs
      # package, only Go binaries per release). Mirrors the homelab cluster
      # deployment in home-infrastructure-flux (apps/sympozium/mcpservers.yaml).
      truenasMcpServer = pkgs.buildGoModule {
        pname = "truenas-mcp";
        version = "0.0.4";

        src = pkgs.fetchFromGitHub {
          owner = "truenas";
          repo = "truenas-mcp";
          rev = "v0.0.4";
          hash = "sha256-R+d6qiFM9mwrAXqA8X+m4/x7+pUTq0zN7jshScSgl0o=";
        };

        vendorHash = "sha256-0A+zS5N+LZ7yRabl6BvovpZPq9NErroW21sRfiMTA+c=";

        subPackages = [ "cmd/truenas-mcp" ];

        meta = {
          description = "Model Context Protocol server for TrueNAS";
          homepage = "https://github.com/truenas/truenas-mcp";
          mainProgram = "truenas-mcp";
        };
      };

      # Wrapper that reads the API key from a sops secret at runtime.
      # TRUENAS_URL is supplied via the server env block below. Connects to
      # the public ingress (truenas.jevy.org, valid LE cert) so no
      # --insecure is needed; switch to the LAN IP + --insecure if running
      # off-network is not desired.
      truenasMcpWrapper = pkgs.writeShellApplication {
        name = "run-truenas-mcp";
        runtimeInputs = [ truenasMcpServer ];
        text = ''
          TRUENAS_API_KEY=$(cat ${config.sops.secrets.truenas_api_key.path})
          export TRUENAS_API_KEY
          exec truenas-mcp "$@"
        '';
      };

      # n8n MCP server wrapper (reads API key from sops secret)
      n8nMcpWrapper = pkgs.writeShellApplication {
        name = "run-n8n-mcp";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
          if [ -f "$SOPS_SECRET_PATH/n8n_api_key" ]; then
            N8N_API_KEY=$(cat "$SOPS_SECRET_PATH/n8n_api_key")
            export N8N_API_KEY
          fi
          exec npx -y n8n-mcp "$@"
        '';
      };

      # Brave Search MCP server, built natively from source — see
      # pkgs/brave-search-mcp-server. Was `npx -y`, which tripped Claude Code's
      # 30s MCP startup budget on npx's per-launch npm-registry version check.
      braveSearchMcpServer = pkgs.callPackage ../../pkgs/brave-search-mcp-server { };

      # Brave Search MCP server wrapper (reads API key from sops secret)
      braveSearchMcpWrapper = pkgs.writeShellApplication {
        name = "run-brave-search-mcp";
        runtimeInputs = [ braveSearchMcpServer ];
        text = ''
          SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
          if [ -f "$SOPS_SECRET_PATH/brave_api_key" ]; then
            BRAVE_API_KEY=$(cat "$SOPS_SECRET_PATH/brave_api_key")
            export BRAVE_API_KEY
          fi
          exec brave-search-mcp-server "$@"
        '';
      };

      # Home Assistant MCP server wrapper (SSE-to-stdio proxy, reads token from sops)
      homeAssistantMcpWrapper = pkgs.writeShellApplication {
        name = "run-homeassistant-mcp";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
          if [ -f "$SOPS_SECRET_PATH/homeassistant_token" ]; then
            HA_TOKEN=$(cat "$SOPS_SECRET_PATH/homeassistant_token")
          fi
          exec npx -y mcp-remote "https://homeassistant.jevy.org/api/mcp" \
            --header "Authorization: Bearer $HA_TOKEN"
        '';
      };

      # Playwright MCP server wrapper (dedicated chromium profile for persistent logins)
      # Runs headed by default — visible browser window, login state survives restarts
      # Output dir is routed to XDG cache so auto-snapshots don't pollute the cwd
      # (previously created `.playwright-mcp/` in whatever directory Claude Code started in)
      playwrightMcpWrapper = pkgs.writeShellApplication {
        name = "run-playwright-mcp";
        text = ''
          PROFILE_DIR="$HOME/.local/share/playwright-mcp/chromium"
          OUTPUT_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/playwright-mcp/output"
          mkdir -p "$PROFILE_DIR" "$OUTPUT_DIR"
          exec ${lib.getExe pkgs.playwright-mcp} \
            --executable-path ${lib.getExe pkgs.chromium} \
            --user-data-dir "$PROFILE_DIR" \
            --output-dir "$OUTPUT_DIR" \
            "$@"
        '';
      };

      # GitHub MCP server wrapper (reads token from sops secret at runtime)
      run-github-mcp-server = pkgs.writeShellApplication {
        name = "run-github-mcp-server";
        text = ''
          GITHUB_PERSONAL_ACCESS_TOKEN=$(cat ${config.sops.secrets.github_personal_access_token.path})
          export GITHUB_PERSONAL_ACCESS_TOKEN
          exec github-mcp-server "$@"
        '';
      };

      # Server definitions shared across all tools
      servers = {
        context7 = {
          command = lib.getExe pkgs.context7-mcp;
        };
        git = {
          command = lib.getExe pkgs.mcp-server-git;
        };
        time = {
          command = lib.getExe pkgs.mcp-server-time;
        };
        playwright = {
          command = "${playwrightMcpWrapper}/bin/run-playwright-mcp";
        };
        kubernetes = {
          command = "${kubernetesWrapper}/bin/run-mcp-kubernetes";
        };
        grafana = {
          command = "${grafanaMcpWrapper}/bin/run-grafana-mcp";
          args = [ "--disable-write" ];
          env = {
            GRAFANA_URL = "https://grafana.jevy.org";
          };
        };
        n8n = {
          command = "${n8nMcpWrapper}/bin/run-n8n-mcp";
          env = {
            MCP_MODE = "stdio";
            N8N_API_URL = "https://n8n.jevy.org";
            LOG_LEVEL = "error";
            DISABLE_CONSOLE_OUTPUT = "true";
          };
        };
        "brave-search" = {
          command = "${braveSearchMcpWrapper}/bin/run-brave-search-mcp";
        };
        truenas = {
          command = "${truenasMcpWrapper}/bin/run-truenas-mcp";
          env = {
            TRUENAS_URL = "truenas.jevy.org";
          };
        };
        homeassistant = {
          command = "${homeAssistantMcpWrapper}/bin/run-homeassistant-mcp";
        };
        linear = {
          # Linear removed the /sse endpoint (deprecated 2026-02, now 404s) in
          # favor of the streamable-HTTP endpoint at /mcp. mcp-remote bridges it
          # to stdio; --prefer-offline skips npx's per-launch registry check.
          command = lib.getExe' pkgs.nodejs "npx";
          args = [ "--prefer-offline" "-y" "mcp-remote" "https://mcp.linear.app/mcp" ];
        };
      };
    in
    {
      # Central MCP config (generates ~/.config/mcp/mcp.json)
      programs.mcp.enable = true;
      programs.mcp.servers = servers;

      # Claude Code: symlink to programs.mcp output
      home.file.".mcp.json".source =
        config.lib.file.mkOutOfStoreSymlink
          "${config.xdg.configHome}/mcp/mcp.json";

      # VSCode Cline: needs { mcp: { servers: {...} } } format
      home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/.keep".text = "";
      home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json".text =
        builtins.toJSON { mcp.servers = servers; };

      # GitHub MCP server wrapper (standalone, not an MCP config entry)
      home.packages = [ run-github-mcp-server ];
    };
}
