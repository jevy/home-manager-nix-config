# MCP (Model Context Protocol) server configuration
# Uses programs.mcp as the single source of truth for all MCP server configs
{ inputs, ... }:
{
  flake.modules.homeManager.mcp =
    { config, pkgs, lib, ... }:
    let
      # Kubernetes MCP server, built natively with buildNpmPackage against a
      # generated npm lockfile (see pkgs/mcp-server-kubernetes) — no npx registry
      # check to trip Claude Code's 30s startup budget. The server shells out to
      # kubectl at runtime, so the wrapper puts it on PATH.
      kubernetesMcpServer = pkgs.callPackage ../../pkgs/mcp-server-kubernetes { };
      kubernetesWrapper = pkgs.writeShellApplication {
        name = "run-mcp-kubernetes";
        runtimeInputs = [ kubernetesMcpServer pkgs.kubectl ];
        text = ''exec mcp-server-kubernetes "$@"'';
      };

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
      #
      # The secret is read by literal path rather than
      # `config.sops.secrets.truenas_api_key.path`, and guarded with `-f`, so
      # this module evaluates on hosts that have no sops-nix at all — the
      # devbox pod holds no key by design. Same pattern as the grafana and
      # brave wrappers. On a sops host the path is identical, so nothing
      # changes there; without it the server starts unauthenticated and
      # fails at first call instead of breaking eval for every host.
      truenasMcpWrapper = pkgs.writeShellApplication {
        name = "run-truenas-mcp";
        runtimeInputs = [ truenasMcpServer ];
        text = ''
          SOPS_SECRET_PATH="$HOME/.config/sops-nix/secrets"
          if [ -f "$SOPS_SECRET_PATH/truenas_api_key" ]; then
            TRUENAS_API_KEY=$(cat "$SOPS_SECRET_PATH/truenas_api_key")
            export TRUENAS_API_KEY
          fi
          exec truenas-mcp "$@"
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

      # Hermes Agent MCP server. Hermes exposes its messaging bridge
      # (conversations_list / messages_read / messages_send / events_poll ...)
      # over **stdio only** — there is no HTTP endpoint, so the cluster Ingress
      # at hermes.jevy.org is no help here. The bridge is therefore
      # `kubectl exec -i` into the gateway pod, which is stdio end to end.
      #
      # Details that are load-bearing, all verified against the running pod
      # (nousresearch/hermes-agent:v2026.8.3, server version 1.28.1):
      #   * the CLI is not on PATH — it lives in the image's venv at
      #     /opt/hermes/.venv/bin/hermes;
      #   * `kubectl exec` lands as root (the s6-overlay image starts root and
      #     drops to uid 1000 itself), so we `su` to `hermes` — otherwise the
      #     session writes root-owned files into the /opt/data PVC that the
      #     real gateway then can't touch;
      #   * HERMES_HOME=/opt/data comes from the pod's env and is inherited by
      #     the exec, so the bridge sees the same config and sessions as the
      #     live agent;
      #   * `-c hermes` picks the gateway container, not the mfp sidecar.
      #
      # Needs a working kubeconfig with exec rights in the hermes namespace, so
      # it only makes sense on hosts that talk to the cluster. Read/poll tools
      # work standalone; sending requires the gateway to be up, which it is by
      # construction here (we are exec'ing into it).
      hermesMcpWrapper = pkgs.writeShellApplication {
        name = "run-hermes-mcp";
        runtimeInputs = [ pkgs.kubectl ];
        text = ''
          exec kubectl -n hermes exec -i deploy/hermes -c hermes -- \
            su -s /bin/sh hermes -c "exec /opt/hermes/.venv/bin/hermes mcp serve"
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
        hermes = {
          command = "${hermesMcpWrapper}/bin/run-hermes-mcp";
        };
      };
    in
    {
      # Which servers to configure. `null` means all of them, which is what
      # every workstation wants. The devbox pod sets an explicit list: it has
      # no display for playwright and no sops-nix for the servers whose tokens
      # are not in its Kubernetes Secret, and `lib.getAttrs` never forces the
      # ones left out — so excluding playwright genuinely keeps chromium out of
      # the pod's closure rather than merely hiding it from the config.
      options.local.mcp.only = lib.mkOption {
        type = with lib.types; nullOr (listOf str);
        default = null;
        example = [
          "kubernetes"
          "grafana"
        ];
        description = "Restrict the configured MCP servers to these names.";
      };

      config =
        let
          selected =
            if config.local.mcp.only == null then servers else lib.getAttrs config.local.mcp.only servers;
        in
        {
          # Central MCP config (generates ~/.config/mcp/mcp.json)
          programs.mcp.enable = true;
          programs.mcp.servers = selected;

          # Claude Code: symlink to programs.mcp output
          home.file.".mcp.json".source =
            config.lib.file.mkOutOfStoreSymlink
              "${config.xdg.configHome}/mcp/mcp.json";

          # pi (pi-mcp-extension, declared in ./pi.nix): same server set at the
          # extension's global config path. Its per-server schema is a superset
          # of {command,args,env} — transport defaults to "stdio", which every
          # server above is (homeassistant rides mcp-remote over stdio).
          # Servers default to lifecycle "lazy": start one in pi with
          # `/mcp:start <name>`, or add `lifecycle = "eager"` to a server in
          # `servers` above to auto-start it on every pi session.
          home.file.".pi/agent/mcp.json".text = builtins.toJSON { mcpServers = selected; };

          # VSCode Cline: needs { mcp: { servers: {...} } } format
          home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/.keep".text = "";
          home.file.".config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json".text =
            builtins.toJSON { mcp.servers = selected; };
        };
    };
}
