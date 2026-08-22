# Local LLM Setup: llama-swap + llama.cpp

One machine now: [mac-work](#mac-work-metal), Metal on an M5 Pro. llama-swap is
an OpenAI-compatible proxy on `127.0.0.1:9292` that auto-swaps llama.cpp server
processes on demand.

The Lenovo P14s ran the same architecture on Vulkan until 2026-08; see
[Retired: Lenovo P14s (Vulkan)](#retired-lenovo-p14s-vulkan) for why it went and
what it taught.

# Retired: Lenovo P14s (Vulkan)

Removed 2026-08. The P14s ran llama-swap on an AMD Radeon 860M iGPU (RDNA 3.5,
Vulkan-only — no ROCm) with the same proxy-on-9292 design as mac-work below.

**Why it went.** The models stopped being used, and the setup was not free to
keep: 22 GB of GGUFs in `/var/lib/llama-swap/models`, plus a from-source
llama-cpp build on every nixpkgs bump. The overlay set `GGML_NATIVE=ON` for Zen
5 AVX-512, which defeats the binary cache by construction, so each bump cost a
5-10 minute local compile for a stack nothing was calling. The machine is an
OpenRouter/DeepSeek client now.

**What was removed:** `flake.overlays.llamaCpp` and `flake.modules.nixos.llamaSwap`
(both in `modules/services/llama-swap.nix`, which now holds only the mac half),
the `nixos.llamaSwap` import in `modules/hosts/lenovo-p14s/default.nix`, the
`overlays.llamaCpp` entry in `modules/hosts/linux-desktop-base.nix`, and the
`local` provider from the Linux halves of `modules/dev/pi.nix` and
`modules/dev/opencode.nix`.

## Two findings worth keeping

**The Mesa RADV warmup hang.** Every model hung at Vulkan warmup until Mesa
26.1.3. The trigger was the default f16 KV cache: warmup ground the GPU
indefinitely, blew past llama-swap's 120s `healthCheckTimeout`, and llama-swap
killed llama-server — so every request came back 502. It reads exactly like a
model or quantization problem and is neither.
Refs: [mesa#15550](https://gitlab.freedesktop.org/mesa/mesa/-/work_items/15550),
llama.cpp #23755, #24307, #23995.

**The systemd sandbox blocks the GPU.** The upstream NixOS module runs
llama-swap under `DynamicUser=true` with strict sandboxing, and three of those
defaults have to be relaxed before Vulkan works at all:

| Override | Why |
|---|---|
| `PrivateUsers=false` | `DynamicUser` + `PrivateUsers` defeats group-based `/dev/dri` access |
| `SupplementaryGroups=render,video` | actually get `/dev/dri` |
| `MemoryDenyWriteExecute=false` | Vulkan shader JIT needs W^X pages |

Plus `VK_ICD_FILENAMES` pointed at the AMD ICD, and `ReadOnlyPaths` for the
models dir.

## Performance it reached (for comparison with the Metal numbers below)

Measured on the performance power profile, Vulkan on the Radeon 860M:

| Model | Prompt processing | Generation |
|---|---|---|
| Qwen3-Coder-30B (18 GB) | ~47 tok/s | ~15-16 tok/s |
| Qwen3.5-35B (21 GB) | ~33-45 tok/s | ~8 tok/s |

Both TTFB ~0.5-0.7s with the model already loaded.

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
