# llama-swap + llama.cpp for local LLM inference — mac-work only.
#
# HISTORY: the Lenovo P14s ran the same proxy on Vulkan (Radeon 860M, RDNA3.5
# iGPU) via `flake.overlays.llamaCpp` + `flake.modules.nixos.llamaSwap`. Both
# were dropped: the machine is an OpenRouter/DeepSeek client now, and the local
# stack was costing 22 GB of GGUFs plus a from-source llama-cpp rebuild
# (`GGML_NATIVE=ON` for Zen 5 AVX-512 defeats the binary cache) on every
# nixpkgs bump, for models that were no longer being used.
#
# Two findings from that setup, kept because they will bite again if it ever
# comes back: every model hung at Vulkan warmup until Mesa 26.1.3 — a RADV
# regression triggered by the default f16 KV cache, which ground the GPU past
# llama-swap's 120s healthCheckTimeout so every request 502'd
# (https://gitlab.freedesktop.org/mesa/mesa/-/work_items/15550, llama.cpp
# #23755/#24307/#23995); and the upstream NixOS module's `DynamicUser` +
# `PrivateUsers` sandbox had to be relaxed (`PrivateUsers=false`,
# `SupplementaryGroups=render,video`, `MemoryDenyWriteExecute=false`) before
# /dev/dri access and Vulkan shader JIT would work at all.
{ ... }:
{
  # ── mac-work ─────────────────────────────────────────────────────────────
  #
  # nix-darwin has no `services.llama-swap` (nor `services.ollama`), so the
  # supervision is a hand-written launchd user agent. llama-swap itself idles at
  # a few MB; it only spawns a llama-server when a request names a model, and
  # unloads it again after `ttl`. That swapping is the whole point here: no two
  # of the models below fit in the working set at once.
  #
  # THE NUMBER THAT DECIDES EVERY QUANT BELOW is not 24 GB. Metal reports its
  # own recommended working set, and on this machine:
  #
  #   $ llama-server --list-devices
  #   MTL0: Apple M5 Pro (18186 MiB, 18185 MiB free)
  #
  # ~18.2 GiB, because `iogpu.wired_limit_mb` is 0 (Apple's default reserve).
  # It can be raised with `sudo sysctl iogpu.wired_limit_mb=21504`, deliberately
  # NOT done here — 24 GB total is not much to starve the OS out of on a work
  # laptop. Every model is therefore sized to leave real KV headroom inside 18.2.
  #
  # The same command also prints, on this machine:
  #
  #   ggml_metal_library_init_from_source: error compiling source
  #   ggml_metal_device_init: - the tensor API is not supported ... - disabling
  #
  # That is the M5 neural-accelerator path being disabled, not a broken install.
  # Metal itself works. Expect a step up in prefill whenever ggml lands the M5
  # tensor-op kernels; nothing to configure until then.
  #
  # No Vulkan overlay is applied here, unlike the NixOS half — nixpkgs'
  # llama-cpp already enables Metal on darwin, and the stock build is in
  # cache.nixos.org, so this costs no compile.
  flake.modules.homeManager.llamaSwapMac =
    { config, pkgs, lib, ... }:
    let
      llama-server = lib.getExe' pkgs.llama-cpp "llama-server";
      modelsDir = "${config.home.homeDirectory}/models";

      yaml = pkgs.formats.yaml { };
      configFile = yaml.generate "llama-swap.yaml" {
        # Metal has to compile shaders on the first load of a new model, and a
        # 12 GiB read from an external disk is not fast either — 120s (the
        # NixOS value) is tight enough to false-negative here.
        healthCheckTimeout = 180;
        logLevel = "info";

        models = {
          # CODING. Dense 27B: the slow, good one. Sized from the r/LocalLLaMA
          # report that drove OpenCode autonomously for ~2h over 1M+ tokens at
          # this exact quant in 16 GB of VRAM — UD-Q3_K_XL is 12.52 GiB, which
          # leaves ~5.7 GiB of KV inside our 18.2. IQ4_XS (14.63 GiB) is the
          # quality-over-context alternative, but it only leaves ~3.5 GiB and
          # will not hold 73k context.
          #
          # Expect ~10-16 tok/s. A community-measured M5 Pro does 16.2 tok/s on
          # a dense 27B, so this is the "ask it something hard and go get a
          # coffee" model, not the interactive one.
          #
          # --reasoning-budget, NOT --reasoning-effort: the flag every recent
          # write-up quotes does not exist in llama-server b10273 (checked). The
          # budget caps thinking tokens instead, which is the same intent —
          # Qwen3.8 defaults to xhigh and will think for a very long time.
          #
          # Sampler values are Qwen3.8's, from the same report.
          # Requires ${modelsDir}/Qwen3.8-27B-UD-Q3_K_XL.gguf
          "qwen3.8-27b" = {
            cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen3.8-27B-UD-Q3_K_XL.gguf -ngl 99 -c 73728 -t 8 -np 1 --jinja --no-webui --reasoning-budget 2048 --temp 0.4 --top-p 0.90 --top-k 15 --min-p 0.02";
            ttl = 300;
          };

          # AGENT / TOOL WORK. Sparse MoE: the fast one. 35B total but only ~3B
          # active per token, and on a bandwidth-bound chip that is a ~5x
          # difference, not a rounding error — a community-measured M5 Pro does
          # 81 tok/s here against 16 tok/s on the dense 27B above. Tool-calling
          # loops are latency-bound, so this is the one to point an agent at.
          #
          # Qwen3.6 rather than 3.8 on purpose: Qwen3.8 ships no small MoE at
          # all (only the 27B dense and the 2.4T-A95B), so the fast slot costs
          # one model generation until that changes.
          #
          # UD-IQ3_S is 12.74 GiB; UD-IQ4_XS (16.51) leaves only ~1.7 GiB of KV
          # and is not worth the trade at this memory tier.
          # Requires ${modelsDir}/Qwen3.6-35B-A3B-UD-IQ3_S.gguf
          "qwen3.6-35b-a3b" = {
            cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen3.6-35B-A3B-UD-IQ3_S.gguf -ngl 99 -c 65536 -t 8 -np 1 --jinja --no-webui";
            ttl = 300;
          };

          # GENERAL CHAT. 4.64 GiB, measured 64-139 tok/s on M4/M5 Pro. Small
          # enough that it can stay resident while you work, which is the actual
          # reason it is here — the other two evict everything.
          # Requires ${modelsDir}/gemma-4-E4B-it-Q4_K_M.gguf
          "gemma4-e4b" = {
            cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/gemma-4-E4B-it-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --jinja --no-webui";
            ttl = 900;
          };
        };
      };
    in
    {
      # llama-cpp is here for llama-server (spawned by llama-swap) and for
      # llama-bench, which is how any claim in this file gets re-checked.
      home.packages = [
        pkgs.llama-cpp
        pkgs.llama-swap
      ];

      # GGUFs are hand-fetched, not Nix-managed — same as the NixOS half. Only
      # the directory is declared.
      home.activation.llamaSwapModelsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${modelsDir}"
      '';

      # 127.0.0.1 only, and the same 9292 the P14s uses so a client config is
      # portable between the two machines. KeepAlive.SuccessfulExit = false
      # restarts on a crash but still honours a deliberate stop.
      launchd.agents.llama-swap = {
        enable = true;
        config = {
          ProgramArguments = [
            "${pkgs.llama-swap}/bin/llama-swap"
            "--listen=127.0.0.1:9292"
            "--config=${configFile}"
          ];
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/llama-swap.out.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/llama-swap.err.log";
          EnvironmentVariables = {
            HOME = config.home.homeDirectory;
            PATH = "${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
        };
      };
    };
}
