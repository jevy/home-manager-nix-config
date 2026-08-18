# Local LLM Setup: llama-swap + llama.cpp

Two machines, one architecture: llama-swap as an OpenAI-compatible proxy on
`127.0.0.1:9292` that auto-swaps llama.cpp server processes on demand, so a
client config is portable between them. [Lenovo P14s](#lenovo-p14s-vulkan) is
Vulkan on an AMD iGPU; [mac-work](#mac-work-metal) is Metal on an M5 Pro.

# Lenovo P14s (Vulkan)

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

---

# mac-work (Metal)

## The number that decides everything: 18.2 GiB, not 24

The machine has 24 GiB of unified memory (`hw.memsize` = 25769803776), but that
is not what Metal will hand to a model. Ask llama.cpp directly:

```
$ llama-server --list-devices
MTL0: Apple M5 Pro (18186 MiB, 18185 MiB free)
```

**~18.2 GiB** is Apple's default GPU working set, because `iogpu.wired_limit_mb`
is `0`. Every quant choice below is sized against 18.2, not 24.

It can be raised:

```bash
sudo sysctl iogpu.wired_limit_mb=21504   # ~21 GiB to the GPU
```

Deliberately **not** set in Nix. 24 GiB total is not much to starve macOS out of
on a work laptop, and the failure mode is swapping, not a clean error. Set it by
hand for a specific experiment if a model is just over the line.

## The M5 neural accelerators are not being used yet

The same command prints, on this machine:

```
ggml_metal_library_init_from_source: error compiling source
ggml_metal_device_init: - the tensor API is not supported in this environment - disabling
```

That is ggml disabling the M5 tensor-op path, not a broken install — Metal
itself works and models run. There is known headroom here (hand-written w8a8
kernels have shown ~1.4x prefill on M5, and MLX has a split-K GEMM PR targeting
the neural accelerators claiming up to 1.62x), but nothing shipping uses it.
Expect a free prefill improvement on some future llama.cpp bump.

## Models

Stored in `~/models/` (hand-fetched, not Nix-managed — same as the P14s).

| Model ID | File | Size | Use case |
|---|---|---|---|
| `qwen3.8-27b` | `Qwen3.8-27B-UD-Q3_K_XL.gguf` | 12.52 GiB | Coding, hard problems |
| `qwen3.6-35b-a3b` | `Qwen3.6-35B-A3B-UD-IQ3_S.gguf` | 12.74 GiB | Agent / tool work, fast general |
| `gemma4-e4b` | `gemma-4-E4B-it-Q4_K_M.gguf` | 4.64 GiB | Quick chat |

All from [unsloth](https://huggingface.co/unsloth). Download with `wget`, not
`curl` (see the P14s section — curl can silently truncate on redirects), and
check the size against `Content-Length`.

### Why these three

**Dense vs sparse is a ~5x decision on this chip, not a rounding error.** From
community-submitted measurements on a real M5 Pro:

| Model | tok/s | TTFT |
|---|---:|---:|
| gemma4:e4b-mlx | 139 / 130 | 27 ms |
| gemma4:26b-mlx | 85 / 84 | ~100 ms |
| **qwen3.6:35b-mlx** (35B-A3B MoE) | **81 / 80** | ~72 ms |
| gemma4:12b-mlx | 66.5 | 101 ms |
| qwen3-coder-next Q4_K_M | 61.4 | 146 ms |
| glm-4.7-flash q8_0 | 52.9 | 176 ms |
| gemma4:31b-mlx | 33.2 | 262 ms |
| qwen3.6:27b-mtp-q4_K_M | 24.2 / 22.3 | ~405 ms |
| **qwen3.6:27b-mlx** (dense) | **16.2 / 16.1 / 15.8** | ~223 ms |

A 35B *sparse* model runs 5x faster than a 27B *dense* one on the same silicon,
because only ~3B parameters are active per token and this machine is
bandwidth-bound. That is why agent work gets the MoE and only deep coding gets
the dense model.

### Per-model rationale

- **`qwen3.8-27b` (coding).** Newest and best per token, and slow.
  UD-Q3_K_XL (12.52 GiB) leaves ~5.7 GiB of KV inside 18.2, which is what makes
  73k context possible; IQ4_XS (14.63 GiB) is the quality-over-context
  alternative but only leaves ~3.5 GiB. Sampler values and the 73k figure come
  from a report that drove OpenCode autonomously for ~2h over 1M+ tokens at this
  exact quant in 16 GB of VRAM.

  **That report was on an RTX 5060 Ti, and the difference matters.** CUDA has
  compute to spare, so prefill was never its bottleneck; here it measures 110
  tok/s. If the work is genuinely agentic — re-reading a large context every
  turn — `qwen3.6-35b-a3b` beats this model on wall-clock even for coding,
  despite being a generation older. Reach for the dense 27B when one hard answer
  is worth the wait, not for a long tool loop.
- **`qwen3.6-35b-a3b` (agent / tool work).** Tool-calling loops are
  latency-bound, so speed beats depth. Qwen3.6 rather than 3.8 on purpose:
  **Qwen3.8 ships no small MoE** — only the 27B dense and the 2.4T-A95B — so the
  fast slot costs one model generation until that changes. UD-IQ3_S is 12.74
  GiB; UD-IQ4_XS (16.51) leaves only ~1.7 GiB of KV and is not worth the trade.
- **`gemma4-e4b` (chat).** Small enough to stay resident while you work; the
  other two evict everything. Longer `ttl` (900s) for that reason.

### Measured here (llama.cpp b10273, Metal, GGUF)

First-party `llama-bench` numbers from this machine (M5 Pro, 24 GB), as distinct
from the community table above. These are the three models actually installed:

| Model | Quant | Size | pp512 (prefill) | tg128 (decode) |
|---|---|---:|---:|---:|
| gemma-4-E4B-it | Q4_K_M | 4.62 GiB | 640.3 ± 0.1 | 65.1 ± 1.0 |
| Qwen3.6-35B-A3B (MoE) | UD-IQ3_S | 12.73 GiB | **668.1 ± 4.7** | **66.6 ± 0.1** |
| Qwen3.8-27B (dense) | UD-Q3_K_XL | 12.51 GiB | **110.7 ± 0.0** | **15.9 ± 0.1** |

**Read those last two rows together.** They are within 0.2 GiB of each other on
disk and in memory, and the MoE is **4.2x faster to decode and 6.0x faster to
prefill**. Same silicon, same quant class, same footprint. That is the whole
argument for pointing agents at `qwen3.6-35b-a3b` and reserving `qwen3.8-27b`
for problems worth waiting on.

The prefill column is the one that decides whether agentic work is bearable:
110 tok/s means a 40k-token context costs ~6 minutes to ingest before the first
token appears, against ~1 minute on the MoE. Long-context prefill, not decode,
is where Apple Silicon actually hurts.

Cross-checks, all landing in the same place: the community M5 Pro measurement
for a dense 27B is 16.2 tok/s, `llmfit` estimated 15.2, a live generation
through llama-swap measured 16.2, and `llama-bench` says 15.9. The bandwidth
roofline is trustworthy even where llmfit's catalogue is not.

### Verified working

- `qwen3.8-27b` loads at the configured `-c 73728` — `/props` reports
  `n_ctx: 73728`, one slot, and the temp/top_p/top_k/min_p values as set. The
  12.51 GiB weights plus 73k of KV do fit inside the 18.2 GiB working set, which
  was the open question when this config was written.
- `--reasoning-budget 2048` works: replies come back with the thinking split
  into `reasoning_content`, separate from `content`.
- `qwen3.6-35b-a3b` returns well-formed OpenAI `tool_calls` with
  `finish_reason: tool_calls`, at 67 tok/s.
- Cold load through llama-swap: ~5s for gemma, ~26s for the 27B (first request
  after a swap pays this; `ttl` keeps it warm afterwards).

Also visible in the backend load line: llama.cpp picks
`libggml-cpu-apple_m4.so`. There is no M5 CPU variant yet, matching the
disabled tensor-op path described above.

### Things that are not worth installing

- **NVFP4 / FP8 `compressed-tensors` builds** (e.g. anything from `mconcat`).
  Blackwell tensor-core formats, served by vLLM. Metal cannot run them.
- **DSpark / DFlash / EAGLE3 repos** (`RadixArk/Kimi-K3-DSpark`,
  `nvidia/Kimi-K2.6-DFlash`, `lightseekorg/kimi-k2.6-eagle3-*`, ...). These are
  speculative-decoding *draft heads*, shipped without embedding or unembedding
  weights and marked `inference: false`. They are accessories to 100B-2.78T
  targets, not models. `llmfit fit` lists several of them as "Perfect" — see
  the header of `modules/dev/llmfit.nix`.
- **Qwen3-Coder-Next.** Smallest useful GGUF is 35.8 GiB.
- **Claude-reasoning distills of Qwen** (`Jackrong/...-Opus-Reasoning-Distilled`,
  "Qwopus"). Trained on 4k-14k samples against DeepSeek-R1's ~700k, and Claude
  has not exposed raw chain-of-thought since Sonnet 3.7 — extended thinking is
  summarized, so these train on summaries. Community testing puts them
  "indistinguishable from the base model" with unpredictable degradations.

## Runtime choice: llama.cpp, not MLX or Ollama

MLX's advantage is real but small. From one person benchmarking the same 24 GB
M4 Pro under both backends, 28 models paired:

**Median MLX gain: 6%.** Range -5% to +30%. The wins were concentrated in newer
architectures (Qwen3.5-4B +30%, Qwen3.5-9B +24%); MoE and older models were a
wash or slightly negative (LFM2-8B-A1B -5%, Qwen3-30B-A3B 0%, gemma-2-2b -4%).

Against that 6%, llama.cpp gets day-zero model support, native MTP that actually
works, one shared mental model with the P14s, and it is what everyone else
quotes flags against. The MLX ecosystem is also badly fragmented right now —
`mlx-lm` silently drops MTP heads during conversion, which is why there are so
many competing forks.

## Speculative decoding: measure before believing

`--spec-type` accepts `draft-mtp`, `draft-dspark`, `draft-dflash`, `draft-eagle3`
and several ngram variants in this build. It is **off** in all three model
entries on purpose. Three independent recent reports had drafters running
*slower* than vanilla on Apple Silicon, including one paper where 3 of 5
speculative configs lost to plain decoding (best case 1.61x at K=6). Turn it on
per-model and confirm with `llama-bench` before keeping it.

Related: a widely-shared 16 GB config quantizes the KV cache (`--cache-type-k
q4_1`). That was measured on an RTX 5060 Ti. On Metal it is contested — the chip
has the memory bandwidth of an RTX 4080 but roughly a tenth of the compute, so
dequantizing KV can cost more than the bandwidth it saves. Measure it here
rather than copying the flag.

## Flags that do not exist in this build

`--reasoning-effort` is quoted in most recent write-ups and is **not** a
llama-server flag in b10273. The equivalent is `--reasoning-budget N` (token
budget for thinking; `-1` unrestricted, `0` immediate end). Qwen3.8 defaults to
`xhigh` and will think for a very long time, hence `--reasoning-budget 2048` on
the coding entry.

## Using it

### pi (primary client)

`homeManager.piDarwin` (`modules/dev/pi.nix`) installs pi and points it at
llama-swap. It defaults to `qwen3.6-35b-a3b` — the fast MoE — because at 668 vs
111 tok/s prefill it is the only one of the two big models that stays pleasant
in an agent loop.

```bash
pi                      # starts on the local MoE
```

Switch models from pi's picker when a question earns the wait: pick
`Qwen3.8-27B (local, slow//deep)` for one hard answer, `Gemma 4 E4B
(local, quick)` for something trivial. Nothing is billed and nothing leaves the
machine.

**pi here is local-only, deliberately.** The Linux half of the module also
carries OpenRouter and DeepSeek providers; this one does not, because
`modules/hosts/mac-work/default.nix` unsets personal API keys in zsh so work
never spends them. `piDarwin` additionally blanks `ANTHROPIC_API_KEY`,
`OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY` and the AWS trio in
pi's own environment, so it cannot auto-discover a provider either. Adding a
remote provider means giving that module its own `models.json` — not pointing
it at `piModelsJson`, whose key comes from personal sops secrets.

### Anything else OpenAI-compatible

The endpoint is `http://127.0.0.1:9292/v1` with any non-empty API key. The
opencode / aider / Python snippets in the P14s section above work unchanged;
only the model IDs differ (`qwen3.8-27b`, `qwen3.6-35b-a3b`, `gemma4-e4b`).

```bash
curl http://127.0.0.1:9292/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.6-35b-a3b","messages":[{"role":"user","content":"Hello"}]}'
```

First request after a swap pays the model load — ~5s for gemma, ~26s for the
27B. After that `ttl` keeps it warm (300s for the big two, 900s for gemma).
`curl http://127.0.0.1:9292/unload` frees the GPU immediately.

## macOS Configuration Details

| File | What it does |
|---|---|
| `modules/services/llama-swap.nix` | `homeManager.llamaSwapMac` — packages, model config, launchd agent |
| `modules/dev/pi.nix` | `homeManager.piDarwin` — pi, local-only provider, defaults to the MoE |
| `modules/hosts/mac-work/default.nix` | Imports both, plus `homeManager.llmfit` |
| `modules/dev/llmfit.nix` | `llmfit`, with the catalogue caveat |

nix-darwin has no `services.llama-swap` (nor `services.ollama`), so supervision
is a hand-written `launchd.agents.llama-swap` user agent — `RunAtLoad`, and
`KeepAlive.SuccessfulExit = false` so a crash restarts but a deliberate stop
sticks. No Vulkan-style overlay is needed: nixpkgs' `llama-cpp` already enables
Metal on darwin and the stock build is in cache.nixos.org, so this costs no
compile.

```bash
# Logs
tail -f ~/Library/Logs/llama-swap.out.log ~/Library/Logs/llama-swap.err.log

# Restart the agent
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.llama-swap

# What Metal thinks it has
llama-server --list-devices

# Re-measure anything claimed in this doc
llama-bench -m ~/models/Qwen3.6-35B-A3B-UD-IQ3_S.gguf -ngl 99
llmfit bench "<model>"   # and submit it upstream; there are no 24 GB M5 Pro rows yet
```

## Provenance

The M5 Pro / M4 Pro tok/s figures are community-submitted measurements from
llmfit's `llmfit-core/data/community/apple-m5-pro/` and `apple-m4-pro/`
directories (92 result rows, late July - mid August 2026), *not* llmfit's own
estimates. Note the M5 Pro rows are from 64 GB / 18-core machines; this one is
24 GB / 15-core, so tok/s should carry over for models that fit but the memory
headroom does not.

Caveat on all of them: 3-run benchmarks with ~300-token outputs on short
prompts. That is the regime that flatters Apple Silicon most — the long-context
prefill cost, which is the real bottleneck for agentic work on a Mac, does not
show up in these numbers at all.
