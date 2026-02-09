# For standalone home-manager configs (macOS)
{ lib, config, inputs, ... }:
{
  # Declare flake.homeConfigurations so multiple modules can contribute
  options.flake.homeConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
  };

  options.configurations.home = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
        };
        options.system = lib.mkOption {
          type = lib.types.str;
        };
      }
    );
    default = {};
  };

  config.flake.homeConfigurations = lib.flip lib.mapAttrs config.configurations.home (
    name: { module, system }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      modules = [ module ];
    }
  );
}
