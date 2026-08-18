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
# Repinning to the v1.1.10 tag is not the way out either: it wants rustc 1.95
# and nixpkgs is on 1.93.
#
# nixpkgs tracks the release tags instead of main, and v1.1.9 — the same version
# the flake input was locked to — is prebuilt in cache.nixos.org for both
# aarch64-darwin and x86_64-linux, so neither host compiles the Rust workspace.
# The cost is that the model catalogue and community benchmark data are only as
# fresh as the nixpkgs bump. Revisit if upstream fixes the test.
# TRUST `doctor` AND `bench`; DO NOT TRUST `fit` AND `recommend`.
#
# The speed model is sound — it predicted 15.2 tok/s for a dense 27B on this
# machine against a community-measured 16.2 tok/s on a real M5 Pro, i.e. the
# bandwidth roofline is within ~7%. What is not sound is the catalogue: llmfit
# appears to enumerate Hugging Face by parameter count without checking what a
# repo actually *is*, so on this machine `llmfit fit` cheerfully offers, as
# "Perfect" runnable chat models scoring 80-86 on quality:
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
      home.packages = [ pkgs.llmfit ];
    };
}
