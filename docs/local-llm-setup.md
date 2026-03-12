# Local LLM Setup: llama-swap + llama.cpp

## Overview

Local LLM inference on the Lenovo P14s using llama-swap as an OpenAI-compatible proxy that auto-swaps llama.cpp server processes on demand. Replaces ollama.

## Hardware

- **GPU**: AMD Radeon 860M iGPU (RDNA 3.5, Vulkan-only, no ROCm)
- **Memory**: 38.8 GB unified memory (shared CPU/GPU)
- **CPU**: AMD Zen 5, 16 threads, AVX-512 support

## Architecture

```
Client (curl, opencode, aider, etc.)
  |
  v
llama-swap (port 9292, localhost only)
  |
  v
llama-server (spawned per-model, one at a time)
  |
  v
Vulkan GPU / CPU (AVX-512)
```

llama-swap is a lightweight proxy that receives OpenAI API requests, extracts the model name, and routes to the correct llama-server process. Only one model is loaded at a time -- when a different model is requested, the current one is unloaded and the new one is loaded. Models auto-unload after 5 minutes (TTL 300s) of inactivity.

## Models

Stored in `/var/lib/llama-swap/models/`:

| Model ID | File | Size | Use case |
|---|---|---|---|
| `qwen3-coder-30b` | `Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf` | ~18 GB | Code generation, debugging |
| `qwen3.5-35b` | `Qwen3.5-35B-A3B-Q4_K_M.gguf` | ~21 GB | General reasoning, summarization |

Both are MoE (Mixture of Experts) models with only 3B active parameters despite the large total parameter count. Q4_K_M quantization. Sourced from [unsloth](https://huggingface.co/unsloth) on Hugging Face.

## Connecting a Client

Any OpenAI-compatible client works by pointing at `http://127.0.0.1:9292/v1`. The `model` field in the request selects which model llama-swap loads.

### curl

```bash
# List available models
curl http://127.0.0.1:9292/v1/models

# Chat completion
curl http://127.0.0.1:9292/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3-coder-30b","messages":[{"role":"user","content":"Hello"}]}'
```

### opencode

In your opencode config, set the provider to use a local OpenAI-compatible endpoint:

```json
{
  "provider": {
    "local": {
      "type": "openai",
      "api_key": "not-needed",
      "api_url": "http://127.0.0.1:9292/v1",
      "models": {
        "qwen3-coder-30b": { "max_tokens": 32768 },
        "qwen3.5-35b": { "max_tokens": 32768 }
      }
    }
  }
}
```

### aider

```bash
aider --openai-api-base http://127.0.0.1:9292/v1 \
      --openai-api-key not-needed \
      --model openai/qwen3-coder-30b
```

### Python (openai SDK)

```python
from openai import OpenAI

client = OpenAI(base_url="http://127.0.0.1:9292/v1", api_key="not-needed")
response = client.chat.completions.create(
    model="qwen3-coder-30b",
    messages=[{"role": "user", "content": "Hello"}],
)
print(response.choices[0].message.content)
```

## Adding a New Model

### Step 1: Download the GGUF file

Use `wget` for large files (curl can silently truncate on redirects):

```bash
sudo wget -O /var/lib/llama-swap/models/NEW_MODEL.gguf \
  "https://huggingface.co/REPO/resolve/main/NEW_MODEL.gguf"
```

Verify the file size matches what HuggingFace reports:

```bash
# Check expected size from HTTP headers
curl -sI -L "https://huggingface.co/REPO/resolve/main/NEW_MODEL.gguf" | grep Content-Length
# Compare with actual
ls -l /var/lib/llama-swap/models/NEW_MODEL.gguf
```

### Step 2: Add the model to the Nix config

Edit `modules/services/llama-swap.nix` and add a new entry under `settings.models`:

```nix
models = {
  # ... existing models ...
  "my-new-model" = {
    cmd = "${llama-server} --port \${PORT} -m ${modelsDir}/NEW_MODEL.gguf -ngl 99 -c 32768 -t 8 --no-webui";
    ttl = 300;
  };
};
```

Key flags to adjust per model:
- `-ngl 99` -- number of GPU layers (99 = all). Reduce if the model doesn't fit in GPU memory
- `-c 32768` -- context window size. Larger uses more memory
- `-t 8` -- CPU threads for prompt processing
- `ttl` -- seconds of inactivity before auto-unloading (0 = never unload)

### Step 3: Rebuild

```bash
rebuildhm
```

### Step 4: Verify

```bash
# Should list the new model
curl http://127.0.0.1:9292/v1/models

# Test it
curl http://127.0.0.1:9292/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"my-new-model","messages":[{"role":"user","content":"Hello"}]}'
```

### Choosing a model

When picking GGUFs from HuggingFace:

- **Q4_K_M** is a good default quantization (quality vs size tradeoff)
- The model + context must fit in GPU memory (~27 GB usable on P14s)
- MoE models (like Qwen3 A3B variants) are efficient -- large parameter count but only a fraction is active per token
- Check that the model architecture is supported by your llama.cpp version

## Removing a Model

1. Remove the entry from `settings.models` in `modules/services/llama-swap.nix`
2. `rebuildhm`
3. Optionally delete the GGUF: `sudo rm /var/lib/llama-swap/models/OLD_MODEL.gguf`

## Qwen3 Thinking Mode

Qwen3 models default to "thinking mode" -- they produce internal reasoning in a `reasoning_content` field before generating visible `content`. This uses extra tokens but improves quality.

To disable thinking, add `/no_think` to the system prompt:

```bash
curl http://127.0.0.1:9292/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-coder-30b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant. /no_think"},
      {"role": "user", "content": "Write a hello world in Python"}
    ]
  }'
```

## NixOS Configuration Details

### Files

| File | What it does |
|---|---|
| `modules/services/llama-swap.nix` | Overlay (Vulkan + native CPU) + NixOS module (service config, models, systemd overrides) |
| `modules/hosts/linux-desktop-base.nix` | Applies the `overlays.llamaCpp` overlay |
| `modules/hosts/lenovo-p14s/default.nix` | Imports `nixos.llamaSwap` (P14s only) |

### llama-cpp overlay

The overlay in `llama-swap.nix` customizes the nixpkgs `llama-cpp` package:

- **Vulkan support** enabled (CUDA/ROCm/Metal disabled)
- **`GGML_NATIVE=ON`** for Zen 5 AVX-512 optimizations (breaks binary cache -- builds locally in ~5-10 min)
- **`NIX_ENFORCE_NO_NATIVE=0`** to allow native CPU instructions in the Nix build

### Systemd service overrides

The upstream NixOS module uses `DynamicUser=true` with strict sandboxing. We override:

- `PrivateUsers=false` so supplementary groups work for GPU access
- `SupplementaryGroups=render,video` for `/dev/dri` access
- `MemoryDenyWriteExecute=false` for Vulkan shader JIT compilation
- `VK_ICD_FILENAMES` environment variable pointing to the AMD Vulkan ICD
- `ReadOnlyPaths` for the models directory

## Troubleshooting

```bash
# Service status
systemctl status llama-swap
journalctl -u llama-swap -f

# Verify Vulkan
vulkaninfo --summary

# Check GPU memory
cat /sys/class/drm/card*/device/mem_info_vram_used

# Watch GPU utilization
radeontop
```

Common issues:

- **502 Bad Gateway**: llama-server crashed. Check `journalctl -u llama-swap -f` and try the request again. Common causes: model file corrupted/truncated, not enough GPU memory, another process using the GPU
- **Model file corrupted**: If llama-server reports "tensor data is not within the file bounds", re-download with `wget` and verify the file size matches the `Content-Length` header
- **Out of GPU memory**: Reduce `-ngl` (fewer GPU layers) or `-c` (smaller context), or close other GPU-using apps

## Performance (observed, performance power profile)

**Qwen3-Coder-30B** (18 GB, Vulkan on Radeon 860M):

- **Prompt processing**: ~47 tok/s
- **Generation**: ~15-16 tok/s
- **TTFB**: ~0.5s (model already loaded)
- **Sustained output**: ~15 tok/s over 1800 tokens

**Qwen3.5-35B** (21 GB, Vulkan on Radeon 860M):

- **Prompt processing**: ~33-45 tok/s
- **Generation**: ~8 tok/s
- **TTFB**: ~0.5-0.7s (model already loaded)
