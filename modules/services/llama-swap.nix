# llama-swap + llama.cpp for local LLM inference — mac-work and lenovo-p14s.
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
  # ── lenovo-p14s (Vulkan) ─────────────────────────────────────────────────
  #
  # Restored 2026-09 after llmfit was calibrated on this machine and turned up
  # a model worth serving. Deliberately NOT the shape it had before.
  #
  # A HOME-MANAGER USER SERVICE, NOT `services.llama-swap`. The entire sandbox
  # fight in the history note above — PrivateUsers=false, SupplementaryGroups,
  # MemoryDenyWriteExecute=false — exists only because the upstream NixOS
  # module runs under `DynamicUser`. A user service runs as jevin, who already
  # has what it needs, and /dev/dri/renderD128 is mode 0666 on this machine
  # anyway (`crw-rw-rw- root render`), so even the render group is moot. None
  # of those overrides are carried over; do not re-add them without first
  # checking whether the service actually runs unprivileged.
  #
  # It also mirrors the mac half, which is a launchd user agent for the same
  # reason, so both hosts now have one shape and one port.
  #
  # NO COMPILE, UNLIKE LAST TIME. This is `pkgs.llama-cpp-vulkan`, a named
  # nixpkgs attribute, so Hydra builds it and it substitutes from
  # cache.nixos.org — verified, and byte-identical to
  # `llama-cpp.override { vulkanSupport = true; }`. Prefer the named attribute
  # precisely because it is the one Hydra builds; an equivalent override is
  # only cached for as long as it keeps hashing to the same thing.
  #
  # This is what made the old setup expensive, and it was never vulkanSupport:
  # it was `flake.overlays.llamaCpp` setting `GGML_NATIVE=ON` for Zen 5
  # AVX-512, which defeats the binary cache by construction. That overlay is
  # NOT reinstated, and not only for build cost — inference here is GPU-bound
  # and bandwidth-limited (measured ~41.7 GB/s, see modules/dev/llmfit.nix), so
  # CPU vectorisation buys nothing for a fully offloaded model.
  #
  # If a future bump does force a rebuild, check `pkgs.llama-cpp-vulkan` still
  # exists before reaching for an override; the override is the fragile path.
  #
  # THE MESA WARMUP HANG IS MOOT. It needed Mesa < 26.1.3; this host is on
  # 26.2.2. The KV cache is q8_0 regardless, which both halves the KV footprint
  # and avoids the f16 path that triggered it.
  #
  # SIZING. The iGPU addresses 25.38 GB (4 GB BIOS carveout + 21.4 GB GTT — see
  # pkgs/llmfit-amd-igpu-gtt.patch). Both models below are ~15.6 GiB of weights;
  # at 32k context with q8_0 KV that lands near 20 GB, leaving ~5 GB for
  # Hyprland and the rest. Raising -c to 64k does not fit. Only one model is
  # resident at a time; llama-swap evicts on demand, which is the point.
  #
  # Both figures below are measured on this machine with `llama-bench -n 128
  # -ngl 99 -r 3`, on AC and the performance power profile. On battery expect
  # roughly half: the same model measured 19.27 vs 34.00 tok/s across that
  # switch during calibration.
  flake.modules.homeManager.llamaSwapLinux =
    { config, pkgs, lib, ... }:
    let
      llamaCppVulkan = pkgs.llama-cpp-vulkan;
      llama-server = lib.getExe' llamaCppVulkan "llama-server";
      modelsDir = "${config.home.homeDirectory}/models";

      yaml = pkgs.formats.yaml { };
      configFile = yaml.generate "llama-swap.yaml" {
        # 16.8 GB off a btrfs root plus Vulkan shader compilation on first load;
        # the NixOS default of 120s false-negatives here the same way it did on
        # the Mac.
        healthCheckTimeout = 180;
        logLevel = "info";

        models = {
          # THERAPY / PERSONAL. Gemma-4 26B-A4B, abliterated. Chosen off the UGI
          # leaderboard for willingness without the edgelord lean that makes most
          # "uncensored" merges useless for this: W/10 8.2, NatInt 29.7, Writing
          # 40.9 (the highest in its class), dark score 2.20 (the lowest), and
          # readability grade 6.3. Stock google/gemma-4-26B-A4B-it scores W/10
          # 1.8 and will redirect you to a professional almost every turn, which
          # is why the abliterated build is the one here; it costs no measurable
          # intelligence (NatInt 34.44 stock vs 35.71 abliterated).
          #
          # Measured: 9.24 +/- 0.78 tok/s. llmfit predicted 7.54, i.e. MoE
          # estimates run conservative — treat them as a floor.
          #
          # `--reasoning off` IS LOAD-BEARING, NOT A PREFERENCE. This GGUF's
          # jinja template turns thinking on by default, and llama-server routes
          # it to `message.reasoning_content` — so without this flag
          # `message.content` comes back EMPTY and finish_reason is "length".
          # Measured: asked to "say hello in one short sentence", it spent all
          # 120 tokens deliberating and never answered. Any OpenAI-shaped client
          # (pi included) reads content and sees nothing.
          #
          # Turning it off also skips the cost UGI records for the thinking
          # variant: +4 NatInt and +7 Writing, for ~5156 chars (~1289 tokens) of
          # thinking per turn. At 9.2 tok/s that is over two minutes of silence
          # before every reply. Re-enable per request if a question earns it.
          #
          # `--reasoning off` is the switch; `--reasoning-budget` (what the mac
          # half uses) caps thinking tokens instead and still exists in b10809.
          # Budget is the right tool when you want thinking but bounded; off is
          # right here, because this model thinks on every turn including
          # trivial ones.
          #
          # Requires ${modelsDir}/Goetia-26B-A4B-v1.3-Absolute-Heretic-ARA.i1-Q4_K_M.gguf
          "goetia-26b-a4b" = {
            cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Goetia-26B-A4B-v1.3-Absolute-Heretic-ARA.i1-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 -np 1 --jinja --no-webui --reasoning off --cache-type-k q8_0 --cache-type-v q8_0";
            ttl = 600;
          };

          # AGENT / TOOL WORK. Qwen's purpose-built agent MoE, 35B total but
          # only 3B active. Measured 9.40 +/- 1.10 tok/s — indistinguishable
          # from the 26B above, because on this chip active experts plus the
          # always-read attention and embeddings dominate and total parameter
          # count barely matters. Pick between these two on behaviour, not size.
          #
          # Q3_K_XL rather than Q4: Q4_K_M is 22.1 GB and would leave ~3 GB for
          # KV and the desktop inside the 25.38 GB pool.
          #
          # Requires ${modelsDir}/Qwen-AgentWorld-35B-A3B-UD-Q3_K_XL.gguf
          "agentworld-35b-a3b" = {
            cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen-AgentWorld-35B-A3B-UD-Q3_K_XL.gguf -ngl 99 -c 32768 -t 8 -np 1 --jinja --no-webui --cache-type-k q8_0 --cache-type-v q8_0";
            ttl = 600;
          };
        };
      };
    in
    {
      # llama-cpp is here for llama-server (spawned by llama-swap) and for
      # llama-bench, which is how any number in this file gets re-checked.
      home.packages = [
        llamaCppVulkan
        pkgs.llama-swap
      ];

      # GGUFs are hand-fetched, not Nix-managed — same as the mac half. Only
      # the directory is declared.
      home.activation.llamaSwapModelsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${modelsDir}"
      '';

      # 127.0.0.1 only, on the same 9292 the Mac uses so a client config is
      # portable between the two machines.
      systemd.user.services.llama-swap = {
        Unit = {
          Description = "llama-swap (local LLM proxy, Vulkan)";
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.llama-swap}/bin/llama-swap --listen=127.0.0.1:9292 --config=${configFile}";
          Restart = "on-failure";
          RestartSec = 5;
          # llama-server loads ~16 GB before it answers a health check.
          TimeoutStartSec = 300;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };

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
