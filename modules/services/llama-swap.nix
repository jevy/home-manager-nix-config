# llama-swap + llama.cpp for local LLM inference (Vulkan)
#
# History: all models used to hang at Vulkan warmup on this box (Radeon 860M,
# RDNA3.5 iGPU). Root cause was a Mesa RADV regression triggered by the default
# f16 KV cache — warmup ground the GPU forever, so llama-swap's 120s
# healthCheckTimeout killed llama-server and every request 502'd. Fixed upstream
# in Mesa >= 26.1.3 (now running 26.1.3); all models verified to generate.
#   Refs: https://gitlab.freedesktop.org/mesa/mesa/-/work_items/15550
#         llama.cpp #23755 (mesa regression), #24307, #23995
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

            # Uncensored Dolphin fine-tunes (replacing the old abliterated 1.7B) for A/B.
            # Fine-tuned, not abliterated → coherent at small sizes; Qwen2.5/Gemma2 bases
            # have no <think> blocks (so no --reasoning-budget needed). All dense, qwen2/
            # gemma2 arch → full Vulkan support.

            # Dolphin 3.0 / Qwen2.5-1.5B. ~1.1GB Q4_K_M — closest match to the old 1.7B.
            # https://huggingface.co/bartowski/Dolphin3.0-Qwen2.5-1.5B-GGUF
            "dolphin3-qwen2.5-1.5b" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Dolphin3.0-Qwen2.5-1.5B-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --jinja --no-webui";
              ttl = 300;
            };

            # Dolphin 3.0 / Qwen2.5-3B. ~2.0GB Q4_K_M — more coherent, still tiny/fast.
            # https://huggingface.co/bartowski/Dolphin3.0-Qwen2.5-3b-GGUF
            "dolphin3-qwen2.5-3b" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Dolphin3.0-Qwen2.5-3b-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --jinja --no-webui";
              ttl = 300;
            };

            # Dolphin 2.9.4 / Gemma2-2B. ~1.7GB Q4_K_M, different lineage to compare.
            # Gemma2 native context is 8K, so -c 8192 (do not over-extend).
            # https://huggingface.co/bartowski/dolphin-2.9.4-gemma2-2b-GGUF
            "dolphin-gemma2-2b" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/dolphin-2.9.4-gemma2-2b-Q4_K_M.gguf -ngl 99 -c 8192 -t 8 --jinja --no-webui";
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
