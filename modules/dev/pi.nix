# Pi terminal coding agent. Linux: OpenRouter + DeepSeek. mac-work: local
# llama-swap models only (see the piModelsJsonMac note below).
{ inputs, ... }:
let
  # Curated cheap models for OpenRouter. Pi will ONLY see these (no auto/Opus).
  # To browse available models: curl -s https://openrouter.ai/api/v1/models | python3 -m json.tool | less
  piModelsJson = builtins.toJSON {
    providers.openrouter = {
      apiKey = "OPENROUTER_API_KEY";
      models = [
        {
          id = "deepseek/deepseek-v4-pro";
          name = "DeepSeek V4 Pro (OR)";
          reasoning = true;
          input = [ "text" ];
          contextWindow = 1048576;
          maxTokens = 384000;
          cost = { input = 0.435; output = 0.87; cacheRead = 0; cacheWrite = 0; };
        }
        {
          id = "deepseek/deepseek-v4-flash";
          name = "DeepSeek V4 Flash (OR)";
          reasoning = true;
          input = [ "text" ];
          contextWindow = 1048576;
          maxTokens = 384000;
          cost = { input = 0.14; output = 0.28; cacheRead = 0; cacheWrite = 0; };
        }
        {
          id = "google/gemini-3.1-flash-lite-preview";
          name = "Gemini 3.1 Flash Lite";
          input = [ "text" "image" ];
          contextWindow = 1048576;
          maxTokens = 65536;
          cost = { input = 0.25; output = 1.5; cacheRead = 0; cacheWrite = 0; };
        }
        {
          id = "moonshotai/kimi-k2.6";
          name = "Kimi K2.6";
          reasoning = true;
          input = [ "text" "image" ];
          contextWindow = 256000;
          maxTokens = 65536;
          cost = { input = 0.74; output = 4.66; cacheRead = 0; cacheWrite = 0; };
        }
        {
          id = "minimax/minimax-m2.7";
          name = "MiniMax M2.7";
          input = [ "text" ];
          contextWindow = 196608;
          maxTokens = 196608;
          cost = { input = 0.3; output = 1.2; cacheRead = 0; cacheWrite = 0; };
        }
      ];
    };
    # No `providers.local` here: the P14s llama-swap is parked (see
    # modules/hosts/lenovo-p14s/default.nix). Re-add one alongside it.
    providers.deepseek = {
      models = [
        {
          id = "deepseek-v4-pro";
          name = "DeepSeek V4 Pro";
          reasoning = true;
          input = [ "text" ];
          contextWindow = 1048576;
          maxTokens = 384000;
          cost = { input = 0.435; output = 0.87; cacheRead = 0; cacheWrite = 0; };
        }
        {
          id = "deepseek-v4-flash";
          name = "DeepSeek V4 Flash";
          reasoning = true;
          input = [ "text" ];
          contextWindow = 1048576;
          maxTokens = 384000;
          cost = { input = 0.14; output = 0.28; cacheRead = 0; cacheWrite = 0; };
        }
      ];
    };
  };

  # mac-work's local models. A SEPARATE document, not a variant of the above:
  # this is a work laptop, and modules/hosts/mac-work/default.nix deliberately
  # unsets ANTHROPIC/OPENAI/GEMINI keys in zsh so personal credentials never get
  # spent on work. Shipping OpenRouter and DeepSeek providers here would walk
  # that back, so the Mac gets local-only — every model below is free, offline
  # and runs on the machine.
  #
  # IDs must match the model keys in llama-swap's settings.models
  # (modules/services/llama-swap.nix, homeManager.llamaSwapMac).
  #
  # contextWindow mirrors each entry's `-c` flag there. Do not raise one without
  # the other: pi will happily pack a prompt llama-server then refuses.
  piModelsJsonMac = builtins.toJSON {
    providers.local = {
      name = "llama-swap (local)";
      baseUrl = "http://127.0.0.1:9292/v1";
      api = "openai-completions";
      apiKey = "no-key";
      compat.supportsDeveloperRole = false;
      models = [
        # Sparse MoE, and the one to reach for by default. Measured on this
        # machine: 668 tok/s prefill, 67 tok/s decode, and it emits well-formed
        # OpenAI tool_calls — which is what an agent loop actually needs.
        {
          id = "qwen3.6-35b-a3b";
          name = "Qwen3.6-35B-A3B (local, fast)";
          reasoning = true;
          input = [ "text" ];
          contextWindow = 65536;
          maxTokens = 65536;
          cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
        }
        # Dense 27B: better per token, 4.2x slower to decode and 6x slower to
        # prefill at the same 12.5 GiB footprint. Worth it for one hard answer,
        # not for a long tool loop — see docs/local-llm-setup.md.
        {
          id = "qwen3.8-27b";
          name = "Qwen3.8-27B (local, slow//deep)";
          reasoning = true;
          input = [ "text" ];
          contextWindow = 73728;
          maxTokens = 73728;
          cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
        }
        # Small and always-warm (ttl 900 vs 300), for quick questions that
        # aren't worth evicting a 12 GiB model over.
        {
          id = "gemma4-e4b";
          name = "Gemma 4 E4B (local, quick)";
          reasoning = false;
          input = [ "text" ];
          contextWindow = 32768;
          maxTokens = 32768;
          cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
        }
      ];
    };
  };

  piRules = ''
    # Shell Commands
    - Use `fd` instead of `find` — `find` commands with `-exec`, `\;`, or `\|` can be problematic. `fd` is already installed.
    - Avoid ANSI-C quoting (`$'...\n...'`) in shell commands.
  '';

  # Kept deliberately small: pi is an occasional tool here, not the daily
  # driver. Dropped 2026-11: pi-lens (plus the ~18 LSP/linter packages it
  # needed on PATH), pi-readseek, pi-plan, pi-finder-subagent, and
  # pi-mcp-extension (a second MCP client fighting pi-mcp-adapter for /mcp).
  #
  # These are npm installs pi performs at startup into ~/.pi/agent/npm, not
  # Nix builds, so versions float. `pi update --extensions` bumps them.
  piSettings = defaultModel: extraPackages: builtins.toJSON {
    inherit defaultModel;
    packages = extraPackages ++ [
      "npm:pi-secret-guard"
      # Footer with context/token usage.
      "npm:pi-powerline-footer"
      # MCP client. Reads ~/.config/mcp/mcp.json (and ~/.mcp.json), written by
      # ./mcp.nix from the same `programs.mcp.servers` Claude Code gets.
      # ./mcp.nix's `disabled` re-emit exists for this adapter's parser.
      "npm:pi-mcp-adapter"
    ];
    # pi >= 1.3 ships a built-in MCP client. pi-mcp-adapter turns it off by
    # writing this entry into settings.json on first start, but this file is a
    # read-only store symlink, so the write fails (EROFS) and it warns on every
    # launch. Declaring the entry here makes the adapter's check a no-op.
    extensions = [ "-builtin:mcp" ];
  };
in
{
  flake.modules.nixos.pi =
    { pkgs, ... }:
    {
      imports = [ inputs.pi-mono.nixosModules.default ];

      environment.systemPackages = [ pkgs.nodejs ];

      programs.pi.coding-agent = {
        enable = true;

        rules = piRules;

        environment = {
          # Redirect npm global prefix to writable dir (Nix store is read-only)
          NPM_CONFIG_PREFIX.value = "/home/jevin/.npm-global";
          # Blank out API keys to prevent pi auto-discovering unwanted providers
          ANTHROPIC_API_KEY.value = "";
          OPENAI_API_KEY.value = "";
          AWS_ACCESS_KEY_ID.value = "";
          AWS_SECRET_ACCESS_KEY.value = "";
          AWS_PROFILE.value = "";
        };
      };
    };

  # Home-manager: pi config files
  flake.modules.homeManager.pi =
    { config, lib, ... }:
    {
      # Curated model list — only cheap models, no auto/Opus
      home.file.".pi/agent/models.json".text = piModelsJson;

      home.file.".pi/agent/settings.json".text = piSettings "deepseek-v4-pro" [
        # web_search + fetch_content (page → markdown). Linux only: it spends
        # the personal Brave key, which mac-work must not touch.
        "npm:pi-web-access"
      ];

      # pi-web-access config. Brave as the default provider: left on `auto` it
      # tries keyless Exa first.
      #
      # Path: with XDG_CONFIG_HOME set (always, here) the package reads
      # $XDG_CONFIG_HOME/pi/web-search.json and never ~/.pi/agent/, despite its
      # README (utils.ts getWebSearchConfigDir). Its cache lives there too. The key is read from the sops secret on each
      # request via the `!command` source, so it never lands in this file.
      #
      # Copied, not symlinked: its /curator command saves settings back into
      # this file, and a store symlink would fail that write (the same EROFS
      # settings.json hit). Rewritten on every switch, so a /curator change
      # lasts until the next rebuild.
      home.activation.piWebSearch =
        let
          json = builtins.toFile "pi-web-search.json" (builtins.toJSON {
            provider = "brave";
            braveApiKey = "!/run/current-system/sw/bin/cat ${config.xdg.configHome}/sops-nix/secrets/brave_api_key";
          });
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run install -D -m 600 ${json} "${config.xdg.configHome}/pi/web-search.json"
        '';

      # Skills are opt-in per project. No global skills loaded by default.
      # To add skills to a project, symlink individual files:
      #   mkdir -p .pi/skills
      #   ln -s ~/code/personal/skills/explaining-code.md .pi/skills/
      #   ln -s ~/code/personal/skills/container-use.md .pi/skills/
    };

  # ── mac-work ─────────────────────────────────────────────────────────────
  #
  # The Linux half above splits pi across two modules: `nixos.pi` installs the
  # agent (via pi-mono's NixOS module) and `homeManager.pi` supplies the
  # config. nix-darwin has no equivalent, so this one module does both, using
  # pi-mono's home-manager module instead — same `programs.pi.coding-agent`
  # option surface. The aarch64-darwin package builds locally (not in
  # cache.nixos.org).
  #
  # LOCAL-ONLY ON PURPOSE. See piModelsJsonMac above — this machine's zsh config
  # deliberately unsets personal API keys, so pi here talks to llama-swap and
  # nothing else. To add a remote provider later, give this module its own
  # models.json with the extra `providers.*` block; do not point it at
  # piModelsJson, whose OpenRouter key comes from personal sops secrets.
  flake.modules.homeManager.piDarwin =
    { config, pkgs, ... }:
    {
      imports = [ inputs.pi-mono.homeManagerModules.default ];

      home.packages = [ pkgs.nodejs ];

      programs.pi.coding-agent = {
        enable = true;
        rules = piRules;

        environment = {
          # npm's global prefix must be writable; the Nix store is not.
          NPM_CONFIG_PREFIX.value = "${config.home.homeDirectory}/.npm-global";
          # Blank out API keys so pi cannot auto-discover a provider that would
          # bill a personal account from a work machine.
          ANTHROPIC_API_KEY.value = "";
          OPENAI_API_KEY.value = "";
          OPENROUTER_API_KEY.value = "";
          GEMINI_API_KEY.value = "";
          AWS_ACCESS_KEY_ID.value = "";
          AWS_SECRET_ACCESS_KEY.value = "";
          AWS_PROFILE.value = "";
        };
      };

      home.file.".pi/agent/models.json".text = piModelsJsonMac;

      # Defaults to the MoE, not the dense 27B: at 668 vs 111 tok/s prefill it
      # is the only one of the two that stays pleasant in an agent loop. Switch
      # per session with pi's model picker when a question earns the wait.
      home.file.".pi/agent/settings.json".text = piSettings "qwen3.6-35b-a3b" [ ];
    };
}
