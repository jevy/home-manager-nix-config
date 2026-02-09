# Shared overlays for all configurations
{ inputs, config, ... }:
{
  flake.overlays = {
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

    # Disable tailscale tests (flaky in nixpkgs)
    tailscale = final: prev: {
      tailscale = prev.tailscale.overrideAttrs (old: {
        doCheck = false;
      });
    };

    # Fix kdenlive build (needs shaderc)
    kdenlive = final: prev: {
      kdePackages = prev.kdePackages // {
        kdenlive = prev.kdePackages.kdenlive.overrideAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ prev.shaderc ];
        });
      };
    };

    # Pin claude-code to specific version
    claudeCode = final: prev: {
      claude-code = prev.claude-code.overrideAttrs (old: rec {
        version = "2.1.37";
        src = prev.fetchzip {
          url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
          hash = "sha256-ijyZCT4LEEtXWOBds8WzizcfED9hVgaJByygJ4P4Yss=";
        };
        npmDepsHash = "sha256-2if3LsTEnC2OQjEgojqgzs8YOXdpoqJijEmVlxmEfzw=";
      });
    };
  };
}
