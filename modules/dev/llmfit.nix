# llmfit: which local models actually fit this machine.
#
# A TUI/CLI that probes RAM, CPU and GPU, then ranks the model catalogue by
# memory fit, estimated tok/s, quality and usable context. `llmfit` alone opens
# the TUI; `llmfit fit`, `recommend --json`, `info <model>`, `bench` and
# `doctor` are the scriptable halves.
#
# Its own module rather than a line in cliBase because cliBase is also imported
# by the headless shop-sdr host, which has no use for a model-sizing tool. It
# used to be inlined in cliLinux — an artifact of the Mac being standalone
# home-manager at the time, not a platform restriction. llmfit's Apple Silicon
# support is first-class: unified memory is read from system_profiler and
# reported as the (shared) VRAM pool, and MLX is one of the runtimes it scores.
#
# NIXPKGS, NOT THE UPSTREAM FLAKE, DELIBERATELY. `inputs.llmfit` pointed at
# main, and main does not build here: llmfit-core's
# `plan::tests::test_moe_offload_is_not_faster_than_gpu` asserts that offloading
# inactive MoE experts to system RAM can never beat keeping the model in VRAM,
# but the offload side of that comparison calls `ddr_bandwidth_gbps`, which with
# no config and no LLMFIT_DDR_BANDWIDTH falls through to a *live measurement of
# the build host's* RAM bandwidth. On Apple unified memory that measures high
# enough to invert the assertion (120.9 tok/s offload vs 102.3 GPU) and the test
# fails — a host-sensitive test masquerading as a pure invariant, so it fails on
# fast machines and passes on Hydra.
#
# nixpkgs tracks the release tags instead of main, and both hosts get a cache
# hit on the unpatched build. The cost is that the model catalogue and community
# benchmark data are only as fresh as the nixpkgs bump.
#
# THE AMD iGPU PATCH (Linux only). Upstream sizes an AMD iGPU from
# `mem_info_vram_total` alone, which is just the BIOS UMA carveout — 4 GB on the
# P14s, not adjustable in its firmware. amdgpu also exposes `mem_info_gtt_total`,
# an aperture defaulting to about half of system RAM (21.4 GB here) that the
# iGPU addresses at the same DDR bandwidth, because it is the same physical
# memory. llama.cpp's Vulkan backend allocates weights out of it. Reading only
# the carveout therefore understates the machine by 6x, and plain `llmfit fit`
# tops out at 3B models while a 14B Q8 fits comfortably.
#
#   before:  GPU: Radeon 840M / 860M Graphics ( 4.00 GB VRAM, Vulkan)
#   after:   GPU: Radeon 840M / 860M Graphics (25.38 GB VRAM, Vulkan)
#
# pkgs/llmfit-amd-igpu-gtt.patch adds GTT to the VRAM figure for integrated
# cards only — a discrete card's GTT is host RAM over PCIe and folding it in
# would badly flatter a dGPU — and leaves `unified_memory` false. That flag is
# reserved upstream for Ryzen AI MAX, and setting it would be actively wrong
# here: it disables the CpuOffload path outright (plan.rs, fit.rs), and on a
# non-MAX APU that path is still real, since GTT caps near half of RAM while
# llama.cpp on the CPU can use all of it. The patch also prints GTT in the
# `doctor` report, and carries two regression tests. 654 upstream tests pass
# with it applied. Upstreamable as-is; drop this once it lands.
#
# Darwin is left unpatched so mac-work keeps its binary cache — the patched code
# is `cfg!(target_os = "linux")`-gated and would be dead weight there anyway.
#
# THE SPEED PATCH, CALIBRATED AGAINST REAL DECODE. Upstream resolves GPU
# bandwidth from a name table covering discrete cards and Strix Halo. An
# ordinary mobile iGPU is in neither list, so it returned None and the
# estimator fell back to a constant calibrated on discrete GPUs: a dense 8B Q8
# came out at 16.1 tok/s, which would need ~130 GB/s of bandwidth on a machine
# that has ~40. The patch routes integrated GPUs to a measured read-streaming
# probe instead, on the grounds that an iGPU has no memory of its own.
#
# It also corrects `quant_bytes_per_param`, which used nominal bit widths.
# Measured against real GGUFs, Q4_K_M is 4.91-5.03 bits per weight (llama.cpp
# mixes Q6_K into the tensors that matter and stores embeddings higher still)
# and Q8_0 is 8.50 (per-block fp16 scale). Nominal understated weight bytes by
# 24% and 6%, and decode is weight-streaming bound, so that error went straight
# into every tok/s figure on every platform.
#
# Calibrated on AC power, performance profile, llama.cpp b10809 Vulkan,
# `llama-bench -n 128 -ngl 99 -r 3`. Verified end to end against llmfit's own
# output across a 6.3x span of weight sizes, a 7.6x span of speeds, two
# quantizations and two architectures:
#
#   model                  quant    llmfit   measured    err
#   qwen3   1.7B           Q4_K_M    31.33      34.00   -7.8%
#   qwen2.5 1.5B           Q4_K_M    40.41      38.15   +5.9%
#   qwen2.5 3B             Q4_K_M    20.09      20.29   -1.0%
#   qwen2.5 7B             Q4_K_M     8.06       8.51   -5.3%
#   qwen2.5 7B             Q8_0       4.81       4.99   -3.7%
#                                        worst case     7.8%
#
# MoE verified separately, since every row above is dense and MoE takes a
# different path through the estimator (active experts only, not full weights):
#
#   Qwen-AgentWorld-35B-A3B  Q3_K_M     8.99       9.40   -4.4%
#
# That run also killed a plausible-sounding wrong model. A naive
# "reads only the active params" roofline predicts 21.5 tok/s for a 35B-A3B and
# is wrong by +129%: measured decode implies ~4.4 GB read per token against
# ~1.3 GB of active weights, because attention, embeddings and shared experts
# are read every token and llama.cpp touches more than the strictly-routed
# experts. llmfit's own MoE decomposition already models this correctly; do not
# "improve" it with active-param arithmetic.
#
# POWER STATE IS NOT A DETAIL. The same qwen3 1.7B measured 19.27 tok/s on
# battery/balanced and 34.00 on AC/performance — a 76% swing. The calibration
# above is for AC/performance. On battery expect roughly half, and treat any
# llmfit speed figure there as an upper bound.
#
# The 7B Q4 (4.36 GiB) and 7B Q8 (7.54 GiB) runs also confirm the GTT patch end
# to end: both exceed the 4 GB carveout and ran fully GPU-resident, which the
# unpatched build said was impossible.
#
# TRUST `doctor`, `bench`, FIT AND SPEED; STILL DO NOT TRUST THE CATALOGUE.
#
# The residual error above is upstream catalogue data, not the estimator:
# parameter counts exclude the token-embedding matrix while GGUFs include it
# (Qwen2.5-1.5B: catalogue 1.50B vs GGUF 1.777B, 1.19x; Qwen2.5-7B: 7.6B vs
# 7.616B, 1.00x). Size-dependent, so no constant fixes it; the shipped
# bandwidth factor is set to bound worst-case error rather than to be
# physically exact, which costs ~2.5% conservatism on well-catalogued models.
#
# What is not sound is the catalogue: llmfit appears to enumerate Hugging Face
# by parameter count without checking what a repo actually *is*, so `llmfit fit`
# cheerfully offers, as "Perfect" runnable chat models scoring 80-86 on quality:
#
#   - RadixArk/Kimi-K3-DSpark, nvidia/Kimi-K2.6-DFlash, z-lab/Kimi-K2.5-DFlash,
#     lightseekorg/kimi-k2.6-eagle3-mla, novita/kimi-k2.6-dspark — every one a
#     speculative-decoding DRAFT HEAD for a 100B-to-2.78T target, shipped
#     without embedding or unembedding weights and marked `inference: false`.
#     Loaded alone they have no vocabulary to decode into.
#   - mconcat/Qwen3.5-27B-...-NVFP4 as its top pick, reported with
#     `runtime: MLX` and `best_quant: mlx-4bit`. It is an NVFP4 W4A4 /
#     FP8 W8A8 compressed-tensors build for vLLM on Blackwell; Metal cannot run
#     NVFP4 and no MLX build of it exists. Its param count (22.1B) and disk
#     figure (12.18 GB) also disagree with the upstream card (~25 GB).
#
# So it stays installed for `llmfit doctor` (hardware detection) and `llmfit
# bench` (measure real tok/s against a running provider, and submit the result
# upstream — the community data is what the estimates are calibrated on, and
# there are no 24 GB M5 Pro rows in it yet). For deciding what to actually run,
# docs/local-llm-setup.md has measured numbers instead of inferred ones.
#
{ ... }:
{
  flake.modules.homeManager.llmfit =
    { pkgs, ... }:
    {
      home.packages = [
        (if pkgs.stdenv.hostPlatform.isLinux then
          pkgs.llmfit.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ../../pkgs/llmfit-amd-igpu-gtt.patch ];
          })
        else
          pkgs.llmfit)
        # writeShellApplication, not writeShellScriptBin: the script shells out
        # to jq and llmfit, and runtimeInputs puts them on its PATH rather than
        # relying on them happening to be in the user's profile.
        (pkgs.writeShellApplication {
          name = "llmfit-shortlist";
          runtimeInputs = [
            pkgs.jq
            pkgs.coreutils
            (if pkgs.stdenv.hostPlatform.isLinux then
              pkgs.llmfit.overrideAttrs (old: {
                patches = (old.patches or [ ]) ++ [ ../../pkgs/llmfit-amd-igpu-gtt.patch ];
              })
            else
              pkgs.llmfit)
          ];
          text = builtins.readFile ../../pkgs/llmfit-shortlist.sh;
        })
      ];

      # Catalogue overlay. The embedded catalogue is current (entries run to
      # 2026-08) but its crawler is indiscriminate about what it picks up and
      # silently misses canonical repos: 1053 of its 11,980 entries are
      # `facebook/` speech models (encodec, mms-tts-*), `google/` includes
      # 2020-era research like `canine-c` and `reformer-crime-and-punishment`,
      # and only 19% of entries carry a date at all — yet it has no entry for
      # google/gemma-4-12B-it or either Ministral-3, all apache-2.0 and
      # ungated. `llmfit update` does not help: it fetches HuggingFace's
      # trending and top-downloaded lists (text-to-speech included, which is
      # where the facebook entries come from), then saved 0 of 234 models here.
      #
      # llmfit reads this overlay from its data dir, same schema as the
      # embedded hf_models.json. Regenerate from the HF API when adding a
      # model; parameters_raw and the config fields must match the real repo
      # or the size and speed estimates are meaningless.
      home.file.".local/share/llmfit/custom_models.json".source =
        ./llmfit-custom-models.json;

      # `llmfit fit` ranks the whole catalogue, and the catalogue cannot carry a
      # sort: MLX draft heads and speech models with 12M "params" top a tok/s
      # sort at 284 tok/s, `--providers google` surfaces canine-c and
      # reformer-crime-and-punishment, and only 19% of entries have a date at
      # all, so date sort is noise. llmfit-shortlist asks `llmfit plan` about
      # the curated list instead — same calibrated estimator, no ranking noise.
      #
      # Caveat worth knowing: llmfit measures RAM bandwidth live on every
      # invocation, so its numbers read low if something else is using memory
      # bandwidth at the time. Run it on an otherwise idle machine.
    };
}
