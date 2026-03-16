# Shared overlays for all configurations
{ inputs, config, ... }:
{
  flake.overlays = {
    # Temporary: linux-firmware 20260309 fixes AMD s2idle regression in 20260221
    linuxFirmware = final: prev: {
      linux-firmware = (import inputs.nixpkgs-master { system = prev.system; }).linux-firmware;
    };
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

  };
}
