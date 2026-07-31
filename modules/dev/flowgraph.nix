# flowgraph — diff-scoped FE→GraphQL→BE→DB flow diagram for a TS monorepo.
# Walks a git ref range (default merge-base(main,HEAD)..HEAD), bridges GraphQL
# operations to their resolvers, follows resolver→service/inngest/prisma/drizzle,
# and emits a Mermaid flowchart with changed nodes highlighted.
#
# Conventions are tuned for covenant-web (Apollo `gql`, `combineResolvers`,
# `@/services/*`, prisma + drizzle), but the core diff→bridge→emit is generic.
# Uses `tsq` at runtime for type-aware blast-radius. tsq is NOT provided by this
# config — it lives in the covenant-web project and lands on PATH via that repo's
# direnv, so the feature is live inside that worktree and flowgraph degrades
# gracefully to a tsq-free spine everywhere else.
{
  flake.modules.homeManager.flowgraph =
    { pkgs, lib, ... }:
    let
      flowgraph = pkgs.runCommandLocal "flowgraph" {
        meta = {
          description = "Diff-scoped FE→GraphQL→BE→DB Mermaid flow diagram";
          mainProgram = "flowgraph";
        };
      } ''
        mkdir -p $out/bin
        install -m755 ${./../../pkgs/flowgraph/flowgraph.mjs} $out/bin/flowgraph
        substituteInPlace $out/bin/flowgraph \
          --replace-fail "@node@" "${lib.getExe pkgs.nodejs}" \
          --replace-fail "@rg@"   "${lib.getExe pkgs.ripgrep}" \
          --replace-fail "@tsq@"  "tsq" \
          --replace-fail "@mmdc@" "${lib.getExe pkgs.mermaid-cli}"
      '';
    in
    {
      home.packages = [ flowgraph ];
    };
}
