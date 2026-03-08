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
            "qwen3-coder-30b" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --no-webui";
              ttl = 300;
            };
            "qwen3.5-35b" = {
              cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/Qwen3.5-35B-A3B-Q4_K_M.gguf -ngl 99 -c 32768 -t 8 --no-webui";
              ttl = 300;
            };
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
        # Allow reading model files
        ReadOnlyPaths = [ modelsDir ];
      };
    };
}
