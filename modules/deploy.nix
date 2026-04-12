# deploy-rs configuration for remote NixOS deployments
# Usage: nix run .#deploy -- .#shop-sdr
{ inputs, config, lib, ... }:
{
  flake.deploy.nodes = {
    shop-sdr = {
      hostname = "192.168.1.163"; # LAN IP (no Tailscale dependency)
      profiles.system = {
        user = "root";
        sshUser = "jevin";
        path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos
          config.flake.nixosConfigurations.shop-sdr;
      };
      # Magic rollback: if SSH connection drops after activation,
      # the system automatically reverts within 30 seconds
      magicRollback = true;
    };
  };

  # deploy-rs checks (validates all deployment configs evaluate correctly)
  flake.checks = lib.mapAttrs
    (_system: deployLib: deployLib.deployChecks config.flake.deploy)
    inputs.deploy-rs.lib;

  # Convenience app: `nix run .#deploy`
  perSystem = { pkgs, system, ... }: {
    apps.deploy = {
      type = "app";
      program = "${inputs.deploy-rs.packages.${system}.default}/bin/deploy";
    };
  };
}
