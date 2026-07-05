# brave-search-mcp-server (native via buildNpmPackage)

Built from source ([brave/brave-search-mcp-server](https://github.com/brave/brave-search-mcp-server))
instead of `npx -y`, which tripped Claude Code's 30 s MCP startup budget on
npx's per-launch npm-registry version check.

## Why the vendored lockfile?

Upstream's committed `package-lock.json` is defective — ~66% of entries are
missing `resolved`/`integrity` URLs ([npm/cli#6301](https://github.com/npm/cli/issues/6301)).
`importNpmLock` rejects it outright, and `fetchNpmDeps` falls back to ad-hoc
registry fetches that fail cert validation in the build sandbox. So we vendor a
regenerated lockfile here and `postPatch` it over upstream's; `buildNpmPackage`
forwards `postPatch` to `fetchNpmDeps`, so the dependency cache is built from the
good lockfile too.

## Regenerate `package-lock.json` (on every version bump)

Requires network access. From a scratch checkout:

```bash
tmp=$(mktemp -d)
git clone --depth 1 --branch v2.0.85 \
  https://github.com/brave/brave-search-mcp-server "$tmp"   # match `version` in default.nix
cd "$tmp"

npm install --package-lock-only            # rebuilds a complete lockfile with resolved+integrity

cp package-lock.json ~/.config/nixpkgs/pkgs/brave-search-mcp-server/package-lock.json
```

## Then

1. If bumping the version, also refresh the `fetchFromGitHub` `hash` in
   `default.nix` (set to `lib.fakeHash`, run `rebuildhm`, copy from the error).
2. Set `npmDepsHash = lib.fakeHash;`, run `rebuildhm`, and copy the reported
   hash into `default.nix`. (Or precompute:
   `nix run nixpkgs#prefetch-npm-deps package-lock.json`.)
3. `rebuildhm`, then check `/mcp` — brave-search should connect instantly.
