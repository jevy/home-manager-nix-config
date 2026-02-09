# Spicetify (Spotify customization)
{ inputs, ... }:
{
  flake.modules.homeManager.spicetify =
    { ... }:
    {
      imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

      programs.spicetify = {
        enable = true;
      };
    };
}
