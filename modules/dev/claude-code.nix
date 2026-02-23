# Claude Code AI coding agent
{ inputs, ... }:
{
  # Pin claude-code to specific version (nixpkgs lags behind)
  flake.overlays.claudeCode = final: prev: {
    claude-code = prev.claude-code.overrideAttrs (old: rec {
      version = "2.1.50";
      src = prev.fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
        hash = "sha256-pSPZzbLhFsE8zwlp+CHB5MqS1gT3CeIlkoAtswmxCZs=";
      };
      # Replace nixpkgs lockfile with one matching this version
      postPatch = ''
        cp ${../../pkgs/claude-code-package-lock.json} package-lock.json
        substituteInPlace cli.js \
          --replace-fail '#!/bin/sh' '#!/usr/bin/env sh'
      '';
      npmDepsHash = "sha256-/oQxdQjMVS8r7e1DUPEjhWOLOD/hhVCx8gjEWb3ipZQ=";
      # overrideAttrs doesn't re-derive npmDeps from the new src because
      # buildNpmPackage computes npmDeps from the original function's args,
      # not from finalAttrs. We must override it explicitly.
      npmDeps = prev.fetchNpmDeps {
        inherit src postPatch;
        name = "claude-code-${version}-npm-deps";
        hash = npmDepsHash;
      };
    });
  };

  flake.modules.homeManager.claudeCode =
    { pkgs, ... }:
    let
      claude-code-router = pkgs.callPackage ../../pkgs/claude-code-router.nix { };
    in
    {
      home.packages = [
        pkgs.claude-code
        claude-code-router
      ];
    };
}
