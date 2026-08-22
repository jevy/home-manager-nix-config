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

  # pi-lens toolchain: LSP servers, formatters and linters on PATH for
  # pi-lens auto-discovery. nixvim bundles its own copies inside the neovim
  # wrapper; the Nix store deduplicates, so this costs no extra disk.
  piLensTools = pkgs: with pkgs; [
    # LSP servers
    nixd
    pyright
    gopls
    typescript-language-server
    typescript
    bash-language-server
    yaml-language-server
    vscode-langservers-extracted # JSON, CSS, HTML, ESLint
    dockerfile-language-server

    # Formatters
    nixfmt
    shfmt
    ruff
    prettier
    taplo

    # Linters & analysis
    shellcheck
    hadolint
    markdownlint-cli2
    golangci-lint
  ];

  piRules = ''
    # Shell Commands
    - Use `fd` instead of `find` — `find` commands with `-exec`, `\;`, or `\|` can be problematic. `fd` is already installed.
    - Avoid ANSI-C quoting (`$'...\n...'`) in shell commands.
  '';
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
          PI_FINDER_MODELS.value = "deepseek/deepseek-v4-flash:medium";
          # Blank out API keys to prevent pi auto-discovering unwanted providers
          ANTHROPIC_API_KEY.value = "";
          OPENAI_API_KEY.value = "";
          AWS_ACCESS_KEY_ID.value = "";
          AWS_SECRET_ACCESS_KEY.value = "";
          AWS_PROFILE.value = "";
        };
      };
    };

  # Home-manager: pi-lens toolchain
  flake.modules.homeManager.pi =
    { config, pkgs, ... }:
    {
      home.packages = piLensTools pkgs;

      # Curated model list — only cheap models, no auto/Opus
      home.file.".pi/agent/models.json".text = piModelsJson;

      # Declarative pi packages (installed on startup)
      home.file.".pi/agent/settings.json".text = builtins.toJSON {
        defaultModel = "deepseek-v4-pro";
        packages = [
          "npm:pi-lens"
          "npm:pi-secret-guard"
          "npm:pi-finder-subagent"
          # MCP client — reads ~/.pi/agent/mcp.json, written by
          # ./mcp.nix from the same `programs.mcp.servers` Claude Code gets.
          "npm:pi-mcp-extension"
          "npm:pi-mcp-adapter"
        ];
      };

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
  # toolchain and config. nix-darwin has no equivalent, so this one module does
  # both, using pi-mono's home-manager module instead — same
  # `programs.pi.coding-agent` option surface, and the aarch64-darwin package
  # exists upstream (0.84.1, builds locally: not in cache.nixos.org).
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

      home.packages = piLensTools pkgs ++ [ pkgs.nodejs ];

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
      #
      # PI_FINDER_MODELS is deliberately unset (the Linux half pins it to a
      # DeepSeek model that does not exist here); pi-finder-subagent falls back
      # to the default model, which is already the fast one.
      home.file.".pi/agent/settings.json".text = builtins.toJSON {
        defaultModel = "qwen3.6-35b-a3b";
        packages = [
          "npm:pi-lens"
          "npm:pi-secret-guard"
          # MCP client — reads ~/.pi/agent/mcp.json, written by
          # ./mcp.nix from the same `programs.mcp.servers` Claude Code gets.
          "npm:pi-mcp-extension"
        ];
      };
    };
}
