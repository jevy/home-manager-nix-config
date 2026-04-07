# Shared overlays for all configurations
{ inputs, config, ... }:
{
  flake.overlays = {
    # MCP server packages from mcp-servers-nix
    mcpServers = inputs.mcp-servers-nix.overlays.default;

    # Build volsync kubectl plugin from source
    volsync = final: prev: {
      volsync = prev.buildGoModule rec {
        pname = "volsync";
        version = "0.14.0";
        src = prev.fetchFromGitHub {
          owner = "backube";
          repo = "volsync";
          rev = "v${version}";
          sha256 = "sha256-vtJlrqbuZ01wo3HRwfSY4RzR5uEKOmNKAmiHIj0CDIU=";
        };
        proxyVendor = true;
        vendorHash = "sha256-kv1HhjZYErO8aLmkMkrhOgEXFKijuc4Lj30UUZhatV8=";
        subPackages = [ "kubectl-volsync" ];
      };
    };

    # Bump claude-code past yanked 2.1.88 (pulled from npm, 404s)
    claudeCode = final: prev: {
      claude-code = prev.claude-code.overrideAttrs (old: rec {
        version = "2.1.92";
        src = prev.fetchzip {
          url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
          hash = "sha256-CLLCtVK3TeXFZ8wBnRRHNc2MoUt7lTdMJwz8sZHpkFM=";
        };
        postPatch = ''
          cp ${../pkgs/claude-code/package-lock.json} package-lock.json
          substituteInPlace cli.js --replace-fail '#!/bin/sh' '#!/usr/bin/env sh'
        '';
        npmDeps = prev.fetchNpmDeps {
          inherit src;
          name = "claude-code-${version}-npm-deps";
          postPatch = ''
            cp ${../pkgs/claude-code/package-lock.json} package-lock.json
          '';
          hash = "sha256-5LvH7fG5pti2SiXHQqgRxfFpxaXxzrmGxIoPR4dGE+8=";
        };
      });
    };

    # Patched lieer: save state after metadata phase so interrupted full pulls
    lieer = final: prev: {
      lieer = prev.lieer.overrideAttrs (old: {
        src = inputs.lieer-src;
        patches = [];
      });
    };

  };
}
