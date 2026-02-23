# QMD — local CLI for hybrid BM25 + vector search over markdown files
# Embeddings and models stored in ~/.cache/qmd/ (default XDG cache)
#
# Systemd timer re-indexes and embeds every 6 hours so the MCP server
# always has fresh vectors.
{ ... }:
{
  flake.modules.homeManager.qmd =
    { pkgs, ... }:
    let
      qmd = pkgs.callPackage ../../pkgs/qmd.nix { };
    in
    {
      home.packages = [ qmd ];

      systemd.user.services.qmd-embed = {
        Unit.Description = "QMD: re-index collections and generate embeddings";
        Service = {
          Type = "oneshot";
          ExecStart = toString (pkgs.writeShellScript "qmd-update-embed" ''
            ${qmd}/bin/qmd update
            ${qmd}/bin/qmd embed
          '');
        };
      };

      systemd.user.timers.qmd-embed = {
        Unit.Description = "Run QMD embed every 6 hours";
        Timer = {
          OnCalendar = "*-*-* 00/6:00:00";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
