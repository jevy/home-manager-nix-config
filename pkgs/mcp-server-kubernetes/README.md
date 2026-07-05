# mcp-server-kubernetes (native via bun2nix)

Upstream ([Flux159/mcp-server-kubernetes](https://github.com/Flux159/mcp-server-kubernetes))
is a Bun project that ships only a binary `bun.lockb` and **no npm lockfile**,
so `buildNpmPackage` can't be used. We build it natively with
[`bun2nix`](https://github.com/nix-community/bun2nix), which needs a text
`bun.lock` (Bun ≥ 1.2) and a generated `bun.nix`.

## Why not npx?

`npx -y mcp-server-kubernetes` does an npm-registry version check on every
launch. Under concurrent MCP startup that regularly exceeded Claude Code's 30 s
connection budget, so the server showed as `✗ failed`. The same command with
`--prefer-offline` starts in ~0.7 s. The kubernetes wrapper in
`modules/dev/mcp.nix` currently uses `--prefer-offline` as an interim; this
package is the durable native replacement.

## Generate `bun.nix` (one-time, and on every version bump)

Requires network access and Bun ≥ 1.2. From a scratch checkout:

```bash
git clone https://github.com/Flux159/mcp-server-kubernetes /tmp/mcp-k8s
cd /tmp/mcp-k8s
git checkout v3.9.2                       # match `version` in default.nix

bun install                               # migrates bun.lockb -> text bun.lock
bunx bun2nix -o bun.nix                    # generate the Nix expression
                                          # (or: nix run github:nix-community/bun2nix -- -o bun.nix)

cp bun.nix ~/.config/nixpkgs/pkgs/mcp-server-kubernetes/bun.nix
```

## Wire it up

1. Fill the `fetchFromGitHub` `hash` in `default.nix` (leave `""`, run
   `rebuildhm`, copy the hash from the error).
2. In `modules/dev/mcp.nix`, add to the module `let` block:
   ```nix
   bun2nixLib = inputs.bun2nix.packages.${pkgs.system}.default;
   kubernetesMcpServer = pkgs.callPackage ../../pkgs/mcp-server-kubernetes {
     bun2nix = bun2nixLib;
   };
   ```
   (add `inputs` to the outer module args — see CLAUDE.md "no specialArgs" rule)
3. Replace the interim `kubernetesWrapper` with one that execs the native
   binary and puts `kubectl` on PATH:
   ```nix
   kubernetesWrapper = pkgs.writeShellApplication {
     name = "run-mcp-kubernetes";
     runtimeInputs = [ kubernetesMcpServer pkgs.kubectl ];
     text = ''exec mcp-server-kubernetes "$@"'';
   };
   ```
4. `rebuildhm`, then check `/mcp` — kubernetes should connect near-instantly.

## Notes

- If the build fails on top-level `await`, set `bunCompileToBytecode = false;`
  in `default.nix` (bytecode compilation forces CommonJS).
- `bun2nix` is a Rust program and slow to compile from source; the
  `nix-community.cachix.org` substituter (already reachable) serves prebuilt
  binaries.
