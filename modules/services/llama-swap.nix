# llama-swap + llama.cpp for local LLM inference (Vulkan)
#
# TODO(broken 2026-06-26): ALL models hang at Vulkan warmup → llama-swap's 120s
# healthCheckTimeout kills llama-server → every request 502s. Stack is currently DOWN.
#   Root cause: Mesa RADV regression on RDNA3/3.5 iGPUs (Krackan/Phoenix 7xx/8xx M),
#   triggered by the default *f16* KV cache. Confirmed reproducible on this box
#   (Radeon 860M, Mesa 26.1.1): warmup grinds the GPU at ~15% forever, never completes
#   (waited 6+ min). Not flash-attn, not the shader cache, not the systemd sandbox.
#   Upstream: https://gitlab.freedesktop.org/mesa/mesa/-/work_items/15550
#   llama.cpp issues: #23755 (mesa regression), #24664, #24307, #23995
#
#   Fixes, in order of preference:
#   1. PREFERRED — `nix flake update nixpkgs` to pull Mesa >= 26.1.3, which fixes it
#      (confirmed in #24307, 2026-06-20). Bumps llama.cpp forward too (currently b9080,
#      latest b9811). Rebuild, then verify both models actually generate.
#   2. Workaround without bumping Mesa — quantized KV cache dodges the f16 trigger
#      (#23995: "26.1.1 fails only with f16 kv cache; works with q8_0"). Add to each
#      model cmd: `-fa on -ctk q8_0 -ctv q8_0`. Bonus: ~halves KV-cache memory.
#   3. Fallback — pin Mesa back to 26.0.8 (also confirmed working in #23995).
#
#   NOTE: once fixed, drop `--flash-attn on` from qwen3-1.7b-uncensored below unless
#   option 2 is used (it's only needed for quantized-V KV cache; otherwise omit it).
{ inputs, ... }:
{
  # Override llama-cpp for Vulkan + native CPU optimizations (Zen 5 AVX-512)
  flake.overlays.llamaCpp = final: prev: {
    llama-cpp = (prev.llama-cpp.override {
      vulkanSupport = true;
      cudaSupport = false;
      rocmSupport = false;
      metalSupport = false;
    }).overrideAttrs (old: {
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DGGML_NATIVE=ON" ];
      preConfigure = ''
        export NIX_ENFORCE_NO_NATIVE=0
        ${old.preConfigure or ""}
      '';
    });
  };

  flake.modules.nixos.llamaSwap =
    { pkgs, lib, ... }:
    let
      llama-server = lib.getExe' pkgs.llama-cpp "llama-server";
      modelsDir = "/var/lib/llama-swap/models";
    in
    {
      services.llama-swap = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9292;

        settings = {
          healthCheckTimeout = 120;
          logLevel = "info";

          models = {
            # Pure attention MoE (qwen3moe arch) — fully Vulkan compatible
            "qwen3-coder-30b" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --jinja --reasoning-budget 0 --no-webui";
              ttl = 300;
            };

            # Uncensored general-purpose (abliterated Qwen3-30B-A3B, same qwen3moe arch)
            # https://huggingface.co/Goekdeniz-Guelmez/Josiefied-Qwen3-30B-A3B-abliterated-v2
            "qwen3-30b-uncensored" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Josiefied-Qwen3-30B-A3B-abliterated-v2.Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --jinja --reasoning-budget 0 --no-webui";
              ttl = 300;
            };

            # Fast uncensored (abliterated Qwen3-1.7B dense, qwen3 arch — full Vulkan support).
            # 1.7B active vs the 30B's 3B → ~half the per-token reads, so ~2x decode tok/s.
            # Q4_0 quant + flash attention for max throughput on the bandwidth-bound iGPU.
            # https://huggingface.co/bartowski/mlabonne_Qwen3-1.7B-abliterated-GGUF
            "qwen3-1.7b-uncensored" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen3-1.7B-abliterated-Q4_0.gguf -ngl 99 -c 32768 -t 8 --flash-attn on --jinja --reasoning-budget 0 --no-webui";
              ttl = 300;
            };

            # BLOCKED on Vulkan: hybrid MoE with DeltaNet SSM layers (qwen35moe arch)
            # - Missing GATED_DELTA_NET Vulkan shader — SSM layers fall back to CPU
            #   https://github.com/ggml-org/llama.cpp/issues/20354
            # - SSM_CONV/SSM_SCAN shaders were added but fused GDN op is still missing
            #   https://github.com/ggml-org/llama.cpp/issues/19957
            # Uncomment once the Vulkan GDN shader lands in llama.cpp
            # "qwen3.5-35b" = {
            #   cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen3.5-35B-A3B-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --no-webui";
            #   ttl = 300;
            # };
          };
        };
      };

      # Ensure models directory exists with correct permissions
      systemd.tmpfiles.rules = [
        "d ${modelsDir} 0755 root root -"
      ];

      # Override service for Vulkan GPU access
      systemd.services.llama-swap.serviceConfig = {
        # Vulkan ICD for AMD
        Environment = [ "VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json" ];
        # DynamicUser + PrivateUsers prevents group-based /dev/dri access
        PrivateUsers = lib.mkForce false;
        SupplementaryGroups = [ "render" "video" ];
        # Vulkan shader compilation needs JIT (W^X pages)
        MemoryDenyWriteExecute = lib.mkForce false;
        # Allow reading model files
        ReadOnlyPaths = [ modelsDir ];
      };
    };
}
