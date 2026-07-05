# Native build of mcp-server-kubernetes.
#
# Upstream is a Bun project (ships only bun.lockb, no npm lockfile), but its
# build is plain `tsc` — Bun is only the package manager, not a runtime dep.
# nixpkgs has no native bun builder, and bun2nix's in-sandbox `bun install`
# re-resolves manifests over the (sealed) network, so we package it with
# buildNpmPackage against a generated npm lockfile instead — the same mechanism
# as pkgs/brave-search-mcp-server. Regenerate the vendored lockfile on version
# bumps; see README.md.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "mcp-server-kubernetes";
  version = "3.9.2";

  src = fetchFromGitHub {
    owner = "Flux159";
    repo = "mcp-server-kubernetes";
    rev = "v${version}";
    hash = "sha256-HYNcASb7QFNXmQGjW0VVemUXPgBdNb/IBzG5x3xkB/E=";
  };

  # Upstream has no npm lockfile; drop in the generated one before deps are
  # fetched (buildNpmPackage forwards postPatch to fetchNpmDeps).
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # `npm run build` (tsc && shx chmod) runs by default; the
  # `mcp-server-kubernetes` bin is installed from package.json. The server
  # shells out to kubectl at runtime — the consuming wrapper puts it on PATH.
  npmDepsHash = "sha256-fXkWRtT7B2zojgaPcW4jV/FrMl6agS44JN1qYpp3HFQ=";

  meta.mainProgram = "mcp-server-kubernetes";
}
