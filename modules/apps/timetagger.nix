# TimeTagger CLI (time tracking against self-hosted instance)
{ ... }:
{
  flake.modules.homeManager.timetagger =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.timetagger_cli ];
    };
}
