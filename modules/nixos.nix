# Provides an option for declaring NixOS configurations.
{ lib, config, inputs, ... }:
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
        };
      }
    );
    default = {};
  };

  config.flake = {
    nixosConfigurations = lib.flip lib.mapAttrs config.configurations.nixos (
      name: { module }:
      lib.nixosSystem {
        modules = [ module ];
      }
    );
  };
}
