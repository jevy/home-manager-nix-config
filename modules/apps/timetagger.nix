# TimeTagger CLI (time tracking against self-hosted instance)
{ ... }:
{
  flake.modules.homeManager.timetagger =
    { config, pkgs, ... }:
    {
      home.packages = [ pkgs.timetagger_cli ];

      sops.templates."timetagger_config" = {
        path = "${config.home.homeDirectory}/.config/timetagger_cli/config.txt";
        content = ''
          api_url = "${config.sops.placeholder.timetagger_api_url}"
          api_token = "${config.sops.placeholder.timetagger_api_token}"
        '';
      };
    };
}
