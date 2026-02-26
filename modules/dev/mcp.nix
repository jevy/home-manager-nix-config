# MCP (Model Context Protocol) server configuration
# Uses programs.mcp as the single source of truth for all MCP server configs
{ inputs, ... }:
{
  flake.modules.homeManager.mcp =
    { config, pkgs, lib, ... }:
    let
      # Container-use MCP server (containerized environments for coding agents)
      containerUse = pkgs.callPackage ../../pkgs/container-use.nix { };

      # Kubernetes MCP server wrapper
      kubernetesWrapper =
        pkgs.runCommand "run-mcp-kubernetes"
          {
            buildInputs = [ pkgs.makeWrapper ];
          }
          ''
            mkdir -p $out/bin
            makeWrapper ${lib.getExe' pkgs.nodejs "npx"} $out/bin/run-mcp-kubernetes \
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
          exec npx n8n-mcp "$@"
        '';
      };

      # Brave Search MCP server wrapper (reads API key from sops secret)
      braveSearchMcpWrapper = pkgs.writeShellApplication {
        name = "run-brave-search-mcp";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
          if [ -f "$SOPS_SECRET_PATH/brave_api_key" ]; then
            BRAVE_API_KEY=$(cat "$SOPS_SECRET_PATH/brave_api_key")
            export BRAVE_API_KEY
          fi
          exec npx -y @brave/brave-search-mcp-server "$@"
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

      # LinkedIn MCP server wrapper (Docker-based, requires profile volume mount)
      # Breaking change Feb 2026: LINKEDIN_COOKIE env var no longer supported.
      # Must create profile first with: uvx linkedin-scraper-mcp --login
      # Profile stored at ~/.linkedin-mcp/profile/
      linkedinMcpWrapper = pkgs.writeShellApplication {
        name = "run-linkedin-mcp";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          # Check if profile exists, warn if not
          if [ ! -d "$HOME/.linkedin-mcp/profile" ]; then
            echo "Warning: LinkedIn profile not found at ~/.linkedin-mcp/profile/" >&2
            echo "Run 'linkedin-login' to create a profile first" >&2
            exit 1
          fi
          exec docker run --rm -i \
            -v "$HOME/.linkedin-mcp:/home/pwuser/.linkedin-mcp" \
            stickerdaniel/linkedin-mcp-server:latest
        '';
      };

      # FHS environment for running linkedin-scraper-mcp --login
      # Needed because patchright contains dynamically linked binaries
      linkedinMcpFHSEnv = pkgs.buildFHSEnv {
        name = "linkedin-mcp-fhs";
        targetPkgs = pkgs: with pkgs; [
          uv
          gcc.cc.lib
          stdenv.cc.cc.lib
          glib
          libGL
          libgbm
          libxkbcommon
          fontconfig
          freetype
          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          libxcb
          libxi
          libxtst
          libxcursor
          libxscrnsaver
          nss
          nspr
          dbus
          cups
          mesa
          libdrm
          alsa-lib
          at-spi2-atk
          at-spi2-core
          gtk3
          gdk-pixbuf
          pango
          cairo
          expat
          libuuid
          systemd
        ];
        runScript = "bash";
      };

      # Helper script to run linkedin-scraper-mcp --login in FHS environment
      linkedinLogin = pkgs.writeShellApplication {
        name = "linkedin-login";
        runtimeInputs = [ linkedinMcpFHSEnv ];
        text = ''
          mkdir -p "$HOME/.linkedin-mcp"
          exec linkedin-mcp-fhs -c "uvx linkedin-scraper-mcp --login"
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
          command = lib.getExe pkgs.playwright-mcp;
          args = [ "--executable-path" (lib.getExe pkgs.chromium) ];
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
        container-use = {
          command = "${containerUse}/bin/container-use";
          args = [ "stdio" ];
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
        linkedin = {
          command = "${linkedinMcpWrapper}/bin/run-linkedin-mcp";
        };
        homeassistant = {
          command = "${homeAssistantMcpWrapper}/bin/run-homeassistant-mcp";
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
      # LinkedIn login helper (for creating profile in FHS environment)
      home.packages = [ run-github-mcp-server linkedinLogin ];
    };
}
