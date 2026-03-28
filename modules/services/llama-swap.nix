# llama-swap + llama.cpp for local LLM inference (Vulkan)
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
