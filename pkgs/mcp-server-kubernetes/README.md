# mcp-server-kubernetes (native via buildNpmPackage)

Built from source ([Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes))
instead of `npx -y mcp-server-kubernetes`, whose per-launch npm-registry version
check tripped Claude Code's 30 s MCP startup budget under concurrent startup.

## Why buildNpmPackage (not bun2nix)?

Upstream is a Bun project and ships only a binary `bun.lockb` (no npm lockfile).
But its build is plain `tsc` — Bun is only the *package manager*, not a runtime
dependency. nixpkgs has no native bun builder, and bun2nix's in-sandbox
`bun install` re-resolves package manifests over the network (which the build
sandbox blocks). So we package it exactly like `pkgs/brave-search-mcp-server`:
generate an npm `package-lock.json`, vendor it, and `postPatch` it into the
source before `fetchNpmDeps` runs.

## Regenerate `package-lock.json` (on every version bump)

Requires network access. From a scratch checkout:

```bash
tmp=$(mktemp -d)
git clone --depth 1 --branch v3.9.2 \
  https://github.com/Flux159/mcp-server-kubernetes "$tmp"   # match `version` in default.nix
cd "$tmp"
rm -f package-lock.json bun.lockb bun.lock

npm install --ignore-scripts            # full install -> complete lockfile with resolved+integrity

cp package-lock.json ~/.config/nixpkgs/pkgs/mcp-server-kubernetes/package-lock.json
```

## Then

1. If bumping the version, also refresh the `fetchFromGitHub` `hash` in
   `default.nix` (set to `lib.fakeHash`, run `rebuildhm`, copy from the error).
2. Set `npmDepsHash = lib.fakeHash;`, run `rebuildhm`, and copy the reported
   hash into `default.nix`.
3. `rebuildhm`, then check `/mcp` — kubernetes should connect instantly.
