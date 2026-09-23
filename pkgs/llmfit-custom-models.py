#!/usr/bin/env python3
"""Regenerate modules/dev/llmfit-custom-models.json.

llmfit's embedded catalogue is current but its crawler only sees HuggingFace's
trending and top-downloaded lists, so it misses canonical repos (google/gemma-4,
both Ministral-3s) and annotates nothing about refusal behaviour. This pulls the
UGI leaderboard (Uncensored General Intelligence, ~1300 rows) for the second
half and the HF API for real config values, then emits entries in llmfit's own
hf_models.json schema.

  ./llmfit-custom-models.py > ../modules/dev/llmfit-custom-models.json

Sizing note: entries must carry true parameters_raw. llmfit multiplies it by
bytes-per-param, so a wrong count silently corrupts both fit and tok/s.
"""
import json, sys, urllib.request

# name -> (provider, use_case). UGI scores are appended to use_case so they show
# up in `llmfit info`, which has no field of its own for them.
PICKS = [
    ("google/gemma-4-12B-it", "Google", "Instruction following, chat", None),
    ("mistralai/Ministral-3-8B-Instruct-2512", "Mistral AI", "Instruction following, chat", None),
    ("mistralai/Ministral-3-3B-Instruct-2512", "Mistral AI", "Instruction following, chat", None),
    ("llmfan46/gemma-4-26B-A4B-it-ultra-uncensored-heretic", "llmfan46",
     "Uncensored chat", "UGI 52.4 W/10 10.0 NatInt 35.7 Writing 45.9"),
    ("Naphula/Goetia-26B-A4B-v1.3-Absolute-Heretic-ARA", "Naphula",
     "Uncensored chat, creative", "UGI 44.1 W/10 9.5 NatInt 33.5 Writing 47.9"),
    ("llmfan46/Qwen3.5-35B-A3B-uncensored-heretic", "llmfan46",
     "Uncensored chat", "UGI 49.6 W/10 10.0 NatInt 35.6 Writing 43.2"),
    ("ArliAI/Qwen3.5-35B-A3B-Derestricted", "ArliAI",
     "Uncensored chat", "UGI 50.8 W/10 10.0 NatInt 28.1 Writing 39.2"),
    ("huihui-ai/Huihui-GLM-4.7-Flash-abliterated", "huihui-ai",
     "Uncensored chat", "UGI 41.2 W/10 9.0 NatInt 23.6 Writing 17.3"),
]

def api(url):
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
    return json.load(urllib.request.urlopen(req))

def ggufs(model):
    short = model.split("/")[-1]
    try:
        hits = api("https://huggingface.co/api/models?filter=gguf&limit=3"
                   "&sort=downloads&direction=-1&search=" +
                   urllib.request.quote(short))
    except Exception:
        return []
    return [{"repo": h["modelId"], "provider": h["modelId"].split("/")[0]} for h in hits]

out = []
for name, provider, use_case, ugi in PICKS:
    try:
        cfg = api(f"https://huggingface.co/{name}/resolve/main/config.json")
        info = api(f"https://huggingface.co/api/models/{name}")
    except Exception as e:
        print(f"skip {name}: {e}", file=sys.stderr)
        continue
    tc = cfg.get("text_config", cfg)
    params = (info.get("safetensors") or {}).get("total")
    if not params:
        print(f"skip {name}: no safetensors param count", file=sys.stderr)
        continue
    b = params / 1e9
    # Expert-count keys differ per architecture: qwen3_5_moe uses
    # num_experts/num_experts_per_tok, gemma4 uses num_experts/top_k_experts,
    # glm4_moe_lite uses n_routed_experts/num_experts_per_tok. Missing either
    # makes llmfit score the model as dense, which understates a 26B-A4B by 6x.
    n_exp = (tc.get("num_experts") or tc.get("num_local_experts")
             or tc.get("n_routed_experts"))
    n_act = tc.get("num_experts_per_tok") or tc.get("top_k_experts")
    e = {
        "name": name, "provider": provider,
        "parameter_count": f"{b:.1f}B", "parameters_raw": params,
        "min_ram_gb": round(b * 0.566, 1), "recommended_ram_gb": round(b * 0.934, 1),
        "min_vram_gb": round(b * 0.513, 1),
        "quantization": "Q4_K_M", "format": "gguf",
        "context_length": tc.get("max_position_embeddings") or 32768,
        "use_case": f"{use_case} [{ugi}]" if ugi else use_case,
        "capabilities": ["tool_use"],
        "languages": ["en"], "pipeline_tag": "text-generation",
        "architecture": (cfg.get("model_type") or "unknown"),
        "hf_downloads": info.get("downloads", 0), "hf_likes": info.get("likes", 0),
        "release_date": (info.get("lastModified") or "")[:10],
        "num_hidden_layers": tc.get("num_hidden_layers"),
        "num_attention_heads": tc.get("num_attention_heads"),
        "num_key_value_heads": tc.get("num_key_value_heads"),
        "head_dim": tc.get("head_dim"),
        "hidden_size": tc.get("hidden_size"),
        "vocab_size": tc.get("vocab_size"),
        "moe_intermediate_size": tc.get("moe_intermediate_size") or tc.get("intermediate_size"),
        "shared_expert_intermediate_size": tc.get("shared_expert_intermediate_size"),
        "license": (info.get("cardData") or {}).get("license") or "unknown",
        "gguf_sources": ggufs(name),
    }
    if n_exp and n_act:
        e.update(is_moe=True, num_experts=n_exp, active_experts=n_act)
    out.append(e)
    print(f"ok {name}: {b:.1f}B experts={n_exp}/{n_act}", file=sys.stderr)

json.dump(out, sys.stdout, indent=2)
