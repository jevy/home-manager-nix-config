# tsq — TypeScript LSP CLI backed by vtsls, with a per-project daemon.
# Multiple Claude Code agents in the same repo share one warm vtsls
# via a unix socket keyed off the project root.
{
  flake.modules.homeManager.tsq =
    { pkgs, lib, ... }:
    let
      tsq = pkgs.runCommandLocal "tsq" {
        meta = {
          description = "TypeScript LSP CLI (vtsls-backed daemon)";
          mainProgram = "tsq";
        };
      } ''
        mkdir -p $out/bin
        install -m755 ${./../../pkgs/tsq/tsq.mjs} $out/bin/tsq
        substituteInPlace $out/bin/tsq \
          --replace-fail "@vtsls@" "${lib.getExe pkgs.vtsls}" \
          --replace-fail "@node@" "${lib.getExe pkgs.nodejs}" \
          --replace-fail "@script@" "$out/bin/tsq"
      '';
    in
    {
      home.packages = [ tsq ];
    };
}
