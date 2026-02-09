# Backup services (restic)
{ ... }:
{
  flake.modules.homeManager.backup =
    { config, pkgs, ... }:
    {
      home.packages = with pkgs; [
        restic
        velero
      ];

      services.restic = {
        enable = true;
        backups = {
          "synology" = {
            repository = "rest:http://restic-server.apps:8000/postgresql";
            passwordFile = config.sops.secrets.restic_password.path;
            initialize = false;
          };
        };
      };
    };
}
