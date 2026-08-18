# OpenCode AI coding agent with OpenRouter provider
#
# Codex auth (ChatGPT OAuth → GPT-5.x) is provided by the
# `opencode-openai-codex-auth` plugin. The plugin is referenced by name in the
# `plugin` list and OpenCode auto-installs it from npm at first run. The full
# OpenAI provider/model block is required by the plugin (their docs reject
# minimal configs), so we vendor their upstream JSON at
# ./opencode-codex-auth/opencode-modern.json and merge its `provider.openai`
# into our settings.
#
# To update the vendored codex-auth config:
#   1. Find the latest tag:
#        gh api repos/numman-ali/opencode-openai-codex-auth/releases/latest --jq .tag_name
#   2. Download it over the existing file:
#        curl -fsSL https://raw.githubusercontent.com/numman-ali/opencode-openai-codex-auth/<TAG>/config/opencode-modern.json \
#          -o modules/dev/opencode-codex-auth/opencode-modern.json
#   3. Run `nix flake check` and rebuild.
{ inputs, ... }:
let
  # Vendored upstream config for the opencode-openai-codex-auth plugin (see
  # the header comment). Shared by the Linux and Mac modules below.
  codexAuthConfig = builtins.fromJSON (builtins.readFile ./opencode-codex-auth/opencode-modern.json);
in
{
  flake.modules.homeManager.opencode =
    { config, pkgs, ... }:
    let
      # Wrap opencode to inject OPENROUTER_API_KEY from sops at runtime
      wrappedOpencode = pkgs.symlinkJoin {
        name = "opencode-wrapped";
        paths = [ pkgs.opencode ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencode \
            --run 'export OPENROUTER_API_KEY=$(cat ${config.sops.secrets.openrouter_api_key.path} 2>/dev/null || true)'
        '';
      };

    in
    {
      programs.opencode = {
        enable = true;
        package = wrappedOpencode;
        enableMcpIntegration = true;
        settings = {
          plugin = codexAuthConfig.plugin;
          provider = {
            openai = codexAuthConfig.provider.openai;
            openrouter = {
              models = {
                "minimax/minimax-m2.5" = { max_tokens = 32768; };
                "google/gemini-2.0-flash-exp" = { max_tokens = 32768; };
                "stepfun/step-3.5-flash:free" = { max_tokens = 32768; };
              };
            };
            local = {
              npm = "@ai-sdk/openai-compatible";
              name = "llama-swap (local)";
              options = {
                baseURL = "http://127.0.0.1:9292/v1";
              };
              models = {
                "qwen3-coder-30b" = {
                  name = "Qwen3-Coder-30B";
                  limit = {
                    context = 32768;
                    output = 32768;
                  };
                };
                "dolphin3-qwen2.5-1.5b" = {
                  name = "Dolphin3 Qwen2.5-1.5B";
                  limit = {
                    context = 32768;
                    output = 32768;
                  };
                };
                "dolphin3-qwen2.5-3b" = {
                  name = "Dolphin3 Qwen2.5-3B";
                  limit = {
                    context = 32768;
                    output = 32768;
                  };
                };
                "dolphin-gemma2-2b" = {
                  name = "Dolphin2.9.4 Gemma2-2B";
                  limit = {
                    context = 8192;
                    output = 8192;
                  };
                };
              };
            };
          };
          model = "openrouter/minimax/minimax-m2.5";
        };
      };
    };

  # mac-work: Fireworks (work key) + the local llama-swap on 127.0.0.1:9292.
  # No OpenRouter, no MCP integration (homeManager.mcp is not imported on
  # mac-work). Model IDs are Fireworks dashboard names — check
  # https://fireworks.ai/models before adding more; limits below are the
  # published context windows, lower them if a deployment disagrees.
  flake.modules.homeManager.opencodeMac =
    { config, pkgs, ... }:
    let
      # Work Fireworks key only. The OpenRouter wrapper above injects a
      # *personal* key from sops, which the work-Mac policy (see the piDarwin
      # notes in ./pi.nix) keeps off this machine — so this wrapper exports
      # only FIREWORKS_API_KEY, and the provider set below carries no
      # openrouter block at all.
      wrappedOpencodeMac = pkgs.symlinkJoin {
        name = "opencode-wrapped-mac";
        paths = [ pkgs.opencode ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencode \
            --run 'export FIREWORKS_API_KEY=$(cat ${config.sops.secrets.fireworks_api_key.path} 2>/dev/null || true)'
        '';
      };
    in
    {
      programs.opencode = {
        enable = true;
        package = wrappedOpencodeMac;
        settings = {
          plugin = codexAuthConfig.plugin;
          provider = {
            openai = codexAuthConfig.provider.openai;
            fireworks = {
              npm = "@ai-sdk/openai-compatible";
              name = "Fireworks (work)";
              options = {
                baseURL = "https://api.fireworks.ai/inference/v1";
                apiKey = "{env:FIREWORKS_API_KEY}";
              };
              models = {
                # Verified against GET /inference/v1/models: 1M context,
                # tools + vision supported.
                "accounts/fireworks/models/kimi-k3" = {
                  name = "Kimi K3";
                  limit = {
                    context = 1048576;
                    output = 32768;
                  };
                };
                "accounts/fireworks/models/qwen3-coder-480b-a35b-instruct" = {
                  name = "Qwen3 Coder 480B";
                  limit = {
                    context = 262144;
                    output = 32768;
                  };
                };
                "accounts/fireworks/models/deepseek-v3p1" = {
                  name = "DeepSeek v3.1";
                  limit = {
                    context = 131072;
                    output = 16384;
                  };
                };
              };
            };
            # Same proxy/port as the Linux half; model names are the Mac
            # llama-swap groups from modules/services/llama-swap.nix.
            local = {
              npm = "@ai-sdk/openai-compatible";
              name = "llama-swap (local)";
              options = {
                baseURL = "http://127.0.0.1:9292/v1";
              };
              models = {
                "qwen3.6-35b-a3b" = {
                  name = "Qwen3.6-35B-A3B (fast MoE)";
                  limit = {
                    context = 65536;
                    output = 8192;
                  };
                };
                "qwen3.8-27b" = {
                  name = "Qwen3.8-27B (slow, good)";
                  limit = {
                    context = 73728;
                    output = 8192;
                  };
                };
                "gemma4-e4b" = {
                  name = "Gemma4 E4B (resident)";
                  limit = {
                    context = 32768;
                    output = 8192;
                  };
                };
              };
            };
          };
          model = "fireworks/accounts/fireworks/models/kimi-k3";
        };
      };
    };
}
