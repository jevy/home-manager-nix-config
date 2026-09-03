# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Always use `rebuildhm` to rebuild — it detects the current machine and runs the right command.

```bash
# Rebuild (works on any machine)
rebuildhm

# Check flake evaluates without building
nix flake check

# Update a single flake input
nix flake update <input-name>
```

## Reviewing code

`flowgraph` maps a branch's diff as a FE→GraphQL→resolver→service→DB flow diagram
(changed files highlighted). From the worktree: `flowgraph --open` → reads the
working-tree diff, renders a PDF, opens it in zathura. Then drive into it from
Neovim with `gd`/`gri`/`grr` (cross the gql→resolver wire) and `<leader>go`/`gi`
(walk the call tree). Full playbook + flags + gotchas: **`pkgs/flowgraph/README.md`**.

Two diff reviewers, split by where the comments have to end up — see the header
of **`modules/dev/herdr.nix`** for hotkeys and the herdr plugin wiring:

| Situation | Tool |
|-----------|------|
| Anything local — an agent's diff, your own work, a past commit | **hunk**, `prefix+d` → fzf picker → scope (`prefix+t` for the same picker in its own tab, for a laptop screen). `c` then **ctrl+s** writes a note; `prefix+shift+s` sends every note to the agent |
| Open PR/MR, comments must reach the forge | `tuicr pr <url>`, or Ctrl+click the link in herdr → pickr chooser → `t` |
| **On a git-spice stack** | the picker's `branch vs stack base` row, or `gs-review` from a shell — both diff against the base `gs` tracks, not main (`gs-review hunk` for the read-only variant) |

The picker's rows are: working tree (live), staged, last commit, pick commit,
pick range, branch vs main, branch vs stack base, stash. Each one
**re-points an already-open hunk pane** rather than opening a second, so
`prefix+d` is both "open the review" and "change what it shows".

`branch vs main` resolves origin/HEAD (then origin/main, origin/master, main,
master); `branch vs stack base` reads `gs ls --json` → `.down.name`, the branch
immediately below in the stack. Both diff with `...`, so a base that moved
after you branched doesn't leak into the diff.

In hunk, `Enter` inserts a newline in a note — **ctrl+s saves it**. Notes stay
local until `prefix+shift+s`, which pushes them into the agent's input and then
deletes them from the pane (that deletion is the receipt).

Agents talk to a live hunk session with `hunk session comment list --type user`
(what you typed), `comment add --focus` (annotate a line and jump the cursor
there), `navigate`, and `reload`. `--type user` vs `--type agent` is exact:
CLI-added notes are always `agent`, even with `--author` set.

Agents read/write tuicr sessions via `tuicr review list` / `comments` / `add`.
The **`tuicr` skill** (global, built by `modules/dev/tuicr.nix` from the pinned
`inputs.tuicr`) teaches agents that CLI plus the routing table above — it exists
because upstream's own skill tells agents to default to tuicr, which is wrong
here: on a local diff tuicr cannot send comments back.

HISTORY: `prefix+d` used to open the reviewr plugin (`u`/`b`/`t` scopes, `s` to
send). It was replaced by hunk for two reasons — hunk separates staged from
unstaged and offers eight scopes to reviewr's three, and hunk has a write API so
an agent can put a note *on a line* instead of only receiving one. The cost was
reviewr's `last turn` scope, which has no hunk equivalent.

## Architecture: Dendritic Pattern with flake-parts

This config follows the **[dendritic pattern](https://github.com/mightyiam/dendritic)**. Every `.nix` file under `modules/` is a flake-parts top-level module, auto-imported via `import-tree`.

### How it works

```
flake.nix
  → flake-parts.lib.mkFlake
    → import-tree ./modules  (auto-discovers all .nix files)
      → each file is a flake-parts module contributing to the shared top-level config
```

### Module anatomy

Each feature module defines **deferredModules** stored in `flake.modules.{nixos,homeManager}.*`:

```nix
# modules/base/nix.nix — outer function receives flake-parts args
{ inputs, ... }:
{
  flake.modules.nixos.nix = { ... }: {
    # NixOS module body
  };
  flake.modules.homeManager.nix = { ... }: {
    # home-manager module body
  };
}
```

**Critical rule: no specialArgs.** Inner deferredModules access `inputs` via closure from the outer flake-parts scope, not through specialArgs injection. If a module needs `inputs.foo`, declare `inputs` in the outer function args.

### Host definitions are composition layers

Hosts (`modules/hosts/*/default.nix`) import feature modules by name:

```nix
{ config, inputs, ... }:
let inherit (config.flake.modules) nixos homeManager; in
{
  configurations.nixos.lenovo-p14s.module = { ... }: {
    imports = [ nixos.boot nixos.network nixos.hyprland ... ];
    home-manager.users.jevin.imports = [ homeManager.zsh homeManager.git ... ];
  };
}
```

- **lenovo-p14s**, **shop-sdr**: NixOS + home-manager via `configurations.nixos` (x86_64-linux)
- **mac-work**: nix-darwin + home-manager via `configurations.darwin` (aarch64-darwin)

### Infrastructure modules

- `modules/flake-parts.nix` — enables flake-parts module system
- `modules/nixos.nix` — `configurations.nixos.*` → `flake.nixosConfigurations`
- `modules/darwin.nix` — `configurations.darwin.*` → `flake.darwinConfigurations`
- `modules/home.nix` — `configurations.home.*` → `flake.homeConfigurations`.
  Currently unused: mac-work moved to nix-darwin, so nothing declares
  `configurations.home` and `flake.homeConfigurations` evaluates empty. Kept as
  scaffolding for a future standalone-HM host.
- `modules/systems.nix` — declares supported systems
- `modules/overlays.nix` — shared overlays (+ `modules/desktop/hyprland.nix` contributes one)

### Adding a new feature module

1. Create `modules/<category>/<name>.nix`
2. Define `flake.modules.nixos.<name>` and/or `flake.modules.homeManager.<name>`
   (or `flake.modules.darwin.<name>` for macOS system-level config)
3. Add the module to the relevant host's imports list
4. `import-tree` auto-discovers the file — no manual registration needed

### Custom packages

Package derivations live in `pkgs/`. Reference from modules via relative path: `pkgs.callPackage ../../pkgs/foo.nix {}`.

### Secrets

Managed by sops-nix (`modules/secrets/sops.nix`). Secrets in `secrets.yaml`, age key at `~/.config/sops/age/keys.txt`.

## Hosts Quick Reference

Three hosts, two base layers:

| Host | Platform | Base | Purpose |
|------|----------|------|---------|
| `lenovo-p14s` | x86_64-linux | `linuxDesktopBase` | Daily driver laptop (OLED, Hyprland) |
| `shop-sdr` | x86_64-linux | `linuxServerBase` | Headless ham radio station (IC-7300, SDRplay, WSPR) |
| `mac-work` | aarch64-darwin | nix-darwin | Work Mac (nix-darwin + home-manager; `darwin-rebuild`, not standalone HM; llama-swap on Metal) |

**Base layers** (`modules/hosts/`):
- `linuxDesktopBase` → pulls in ~20 nixos.* + ~30 homeManager.* modules (desktop, audio, Hyprland, dev tools, etc.)
- `linuxServerBase` → minimal: nix, user, zsh, tailscale, network, SSH, node exporter

## Module Categories

All under `modules/`. Each file can define `flake.modules.nixos.*`, `flake.modules.homeManager.*`, and/or `flake.modules.darwin.*`.

| Category | What's there |
|----------|-------------|
| `apps/` | User apps: mutt, spicetify, ncspot, 1Password, timetagger |
| `base/` | Foundational: nix settings, user account, fonts |
| `desktop/` | Hyprland, audio (PipeWire), stylix theming, ashell bar, mako, steam; on mac-work the tiling WM — `aerospace.nix` and `yabai.nix`, selected by `windowManager` in the mac-work host. Read the chosen one's header before touching it: both record measured behaviour that contradicts the upstream docs. |
| `dev/` | Dev tools: git, git-spice, hunk, nixvim, claude-code, opencode, pi, mcp servers, qmd, flowgraph |
| `hardware/` | Hardware-specific: lenovo-p14s quirks |
| `hosts/` | Host definitions + base layers (composition entry points) |
| `secrets/` | sops-nix setup |
| `services/` | Systemd services: backup, boot, docker, tailscale, kanata, ham radio, etc. `llama-swap.nix` is mac-work only now (`homeManager.llamaSwapMac`, Metal, launchd agent) — the P14s Vulkan half was retired 2026-08; local-model sizing, measured tok/s and that retirement live in `docs/local-llm-setup.md`. |
| `shell/` | Shell: zsh, ghostty, ranger, yazi, CLI tools, SSH config |
| Infrastructure | `flake-parts.nix`, `nixos.nix`, `home.nix`, `systems.nix`, `overlays.nix`, `meta.nix`, `deploy.nix` |
