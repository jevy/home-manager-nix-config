# Native build of mcp-server-kubernetes.
#
# Upstream is a Bun project that ships only a binary bun.lockb (no npm
# lockfile), so buildNpmPackage cannot be used. bun2nix consumes a generated
# bun.nix (checked in alongside this file) and compiles a standalone binary via
# `bun build --compile` — no node_modules or npx at runtime, sub-second startup.
#
# The generated ./bun.nix must be regenerated on every version bump; see
# README.md for the one-time steps.
{
  bun2nix,
  fetchFromGitHub,
}:
bun2nix.mkDerivation {
  pname = "mcp-server-kubernetes";
  version = "3.9.2";

  src = fetchFromGitHub {
    owner = "Flux159";
    repo = "mcp-server-kubernetes";
    rev = "v3.9.2";
    hash = ""; # fill from first build error, then rebuild
  };

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # Entry point (compiles to the `mcp-server-kubernetes` bin). The server shells
  # out to `kubectl` at runtime — the consuming wrapper is responsible for
  # putting kubectl on PATH.
  module = "src/index.ts";
}
