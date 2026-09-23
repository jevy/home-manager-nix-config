#!/usr/bin/env bash
# Curated shortlist with calibrated numbers.
#
# `llmfit fit` sorts the whole 11,980-entry catalogue, which is full of entries
# that break any sort: MLX draft heads and speech models with 12M "params" top
# a tok/s sort at 284 tok/s, and `--providers google` surfaces canine-c and
# reformer-crime-and-punishment. So this asks `llmfit plan` about a known list
# instead, which uses the same calibrated estimator without the ranking noise.
#
# The list is whatever is in llmfit-custom-models.json. Edit that (or rerun
# pkgs/llmfit-custom-models.py) to change what shows up here.
set -uo pipefail
CUSTOM="${LLMFIT_CUSTOM_MODELS:-$HOME/.local/share/llmfit/custom_models.json}"
CTX="${1:-8192}"

if [ ! -f "$CUSTOM" ]; then
  echo "no custom model list at $CUSTOM" >&2; exit 1
fi

printf '%-46s %8s %10s %9s  %s\n' MODEL TOK/S FIT VRAM NOTES
printf '%.0s-' {1..108}; echo
jq -r '.[] | [.name, (.use_case // "")] | @tsv' "$CUSTOM" | while IFS=$'\t' read -r name use; do
  json=$(llmfit plan "$name" --context "$CTX" --quant Q4_K_M --json 2>/dev/null) || continue
  read -r tps fit vram < <(printf '%s' "$json" | jq -r '
    (.run_paths[] | select(.path=="gpu")) as $g
    | "\($g.estimated_tps // 0) \($g.fit_level // "?") \(($g.minimum.vram_gb) // 0)"')
  printf '%-46s %8.1f %10s %8.1fG  %s\n' "${name##*/}" "$tps" "$fit" "$vram" "$use"
done | sort -k2 -rn
