# Shared option for the Second Brain Obsidian vault base path
{ ... }:
{
  flake.modules.homeManager.secondBrain =
    { lib, ... }:
    {
      options.secondBrain.basePath = lib.mkOption {
        type = lib.types.str;
        default = "/home/jevin/Second Brain Obsidian/Second Brain";
        description = "Base path to the Second Brain Obsidian vault";
      };
    };
}
