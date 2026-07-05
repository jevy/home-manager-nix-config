# Native build of brave-search-mcp-server.
#
# Upstream commits a broken package-lock.json: ~66% of entries are missing
# `resolved`/`integrity` URLs (npm bug npm/cli#6301), so neither importNpmLock
# nor fetchNpmDeps can consume it (fetchNpmDeps falls back to ad-hoc registry
# fetches that fail). We vendor a regenerated lockfile (./package-lock.json) and
# postPatch it over upstream's — buildNpmPackage forwards postPatch to
# fetchNpmDeps, so the dependency cache is built from the good lockfile too.
#
# The vendored lockfile must be regenerated on every version bump; see README.md.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "brave-search-mcp-server";
  version = "2.0.85";

  src = fetchFromGitHub {
    owner = "brave";
    repo = "brave-search-mcp-server";
    rev = "v${version}";
    hash = "sha256-u9NE9Pqzzt7AIzeOxduDNUVzi2chRa1dRydmnbFB4FU=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # `npm run build` (tsc) runs by default; the `brave-search-mcp-server` bin is
  # installed from package.json. Recompute this hash whenever the vendored
  # lockfile changes.
  npmDepsHash = "sha256-+3RQtADH5l+cXyBEEBOlkcuppxH5UZLVJ6KIxv6sezo=";

  meta.mainProgram = "brave-search-mcp-server";
}
