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
  configurations.nixos.framework.module = { ... }: {
    imports = [ nixos.boot nixos.network nixos.hyprland ... ];
    home-manager.users.jevin.imports = [ homeManager.zsh homeManager.git ... ];
  };
}
```

- **framework**: Full NixOS + home-manager (x86_64-linux)
- **mac-work**: Standalone home-manager via `configurations.home` (aarch64-darwin)

### Infrastructure modules

- `modules/flake-parts.nix` — enables flake-parts module system
- `modules/nixos.nix` — `configurations.nixos.*` → `flake.nixosConfigurations`
- `modules/home.nix` — `configurations.home.*` → `flake.homeConfigurations`
- `modules/systems.nix` — declares supported systems
- `modules/overlays.nix` — shared overlays (+ `modules/desktop/hyprland.nix` contributes one)

### Adding a new feature module

1. Create `modules/<category>/<name>.nix`
2. Define `flake.modules.nixos.<name>` and/or `flake.modules.homeManager.<name>`
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
| `lenovo-p14s` | x86_64-linux | `linuxDesktopBase` | Daily driver laptop (OLED, Hyprland, llama-swap) |
| `shop-sdr` | x86_64-linux | `linuxServerBase` | Headless ham radio station (IC-7300, SDRplay, WSPR) |
| `mac-work` | aarch64-darwin | standalone HM | Work Mac (home-manager only, no NixOS) |

**Base layers** (`modules/hosts/`):
- `linuxDesktopBase` → pulls in ~20 nixos.* + ~30 homeManager.* modules (desktop, audio, Hyprland, dev tools, etc.)
- `linuxServerBase` → minimal: nix, user, zsh, tailscale, network, SSH, node exporter

## Module Categories

All under `modules/`. Each file can define `flake.modules.nixos.*` and/or `flake.modules.homeManager.*`.

| Category | What's there |
|----------|-------------|
| `apps/` | User apps: mutt, spicetify, ncspot, 1Password, timetagger, beads |
| `base/` | Foundational: nix settings, user account, fonts |
| `desktop/` | Hyprland, audio (PipeWire), stylix theming, ashell bar, mako, steam |
| `dev/` | Dev tools: git, nixvim, claude-code, opencode, pi, mcp servers, qmd |
| `hardware/` | Hardware-specific: lenovo-p14s quirks |
| `hosts/` | Host definitions + base layers (composition entry points) |
| `secrets/` | sops-nix setup |
| `services/` | Systemd services: backup, boot, docker, tailscale, kanata, llama-swap, ham radio, etc. |
| `shell/` | Shell: zsh, ghostty, ranger, yazi, CLI tools, SSH config |
| Infrastructure | `flake-parts.nix`, `nixos.nix`, `home.nix`, `systems.nix`, `overlays.nix`, `meta.nix`, `deploy.nix` |
