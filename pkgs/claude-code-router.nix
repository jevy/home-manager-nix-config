{
  lib,
  stdenv,
  fetchurl,
  nodejs,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "claude-code-router";
  version = "1.0.73";

  src = fetchurl {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz";
    hash = "sha256-TAh+qdmY6bcFRhEnpVYmrygs5OPmrob0SWGBch7P2Wg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@musistudio/claude-code-router
    cp -r . $out/lib/node_modules/@musistudio/claude-code-router

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/claude-code-router \
      --add-flags "$out/lib/node_modules/@musistudio/claude-code-router/dist/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Claude Code Router - MCP server router for Claude";
    homepage = "https://www.npmjs.com/package/@musistudio/claude-code-router";
    license = lib.licenses.mit;
    mainProgram = "claude-code-router";
    platforms = lib.platforms.all;
  };
}
