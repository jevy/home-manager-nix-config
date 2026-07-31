# Provides an option for declaring nix-darwin (macOS) configurations.
# Mirrors modules/nixos.nix: configurations.darwin.<name>.module → a
# deferredModule that becomes flake.darwinConfigurations.<name>.
{ lib, config, inputs, ... }:
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
        };
      }
    );
    default = {};
  };

  config.flake.darwinConfigurations = lib.flip lib.mapAttrs config.configurations.darwin (
    name: { module }:
    inputs.nix-darwin.lib.darwinSystem {
      modules = [ module ];
    }
  );
}
