# Backup tooling (packages only).
#
# There used to be a `services.restic` block here declaring a "synology" backup
# against rest:http://restic-server.apps:8000/postgresql. It never ran, and
# could not have:
#
#   1. No `paths` were set, so home-manager generated a unit with no ExecStart
#      and systemd refused it ("Service has no ExecStart=. Refusing."), which
#      also left restic-backups-synology.timer inactive rather than merely idle.
#   2. That repo host is Kubernetes-cluster-internal; it does not resolve from
#      the laptop, so even a fixed unit would have failed to connect.
#   3. The repo path is /postgresql: it was a destination for in-cluster
#      database dumps, never for laptop files.
#
# It was removed rather than fixed because a broken unit looks like a configured
# one, which is how it sat silently failing on every boot. Laptop file backups
# now live in modules/services/laptop-backup.nix (rsync to TrueNAS, plain files
# plus a dated attic). Postgres backups belong in the cluster, not here.
{ ... }:
{
  flake.modules.homeManager.backup =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        restic
        velero
      ];
    };
}
