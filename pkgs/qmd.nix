# qmd: On-device hybrid search (BM25 + vector) for markdown files
# https://github.com/jevy/qmd (fork of tobi/qmd with community fixes)
#
# The upstream repo has no package-lock.json, so we generate one from the
# published npm tarball and inject it at build time.
#
# node-llama-cpp's postinstall tries to git-clone + cmake-build llama.cpp,
# which fails in the nix sandbox. We skip all postinstall scripts and
# rebuild only better-sqlite3 via node-gyp directly. The prebuilt binaries
# ship in @node-llama-cpp/linux-x64 but node-llama-cpp's detectGlibc
# checks standard paths (/lib, /usr/lib, $LD_LIBRARY_PATH). On NixOS we
# set LD_LIBRARY_PATH so the detection passes and the .so files can find
# libstdc++ and libvulkan (for GPU-accelerated inference on Intel iGPU).
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
  python3,
  stdenv,
  vulkan-loader,
}:

buildNpmPackage rec {
  pname = "qmd";
  version = "1.0.7-jevy-2026-03-04";

  src = fetchFromGitHub {
    owner = "jevy";
    repo = "qmd";
    rev = "0230d657c9bd9543c0c8182f594a7e1e631f57e9"; # main with 7 community PRs merged
    hash = "sha256-rqRKA98Tn/1t0WrYKGghIc4ywtUnLtmqJYaVEnpTa6Y=";
  };

  # Upstream has no lockfile; inject the one we generated
  postPatch = ''
    cp ${./qmd-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-DQ8jJmiwrVae2/zSlG7iSxNnRmOjvEOpqqZuWBdZPnI=";

  nodejs = nodejs_22;

  # better-sqlite3 uses node-gyp which needs python3
  nativeBuildInputs = [ python3 ];

  # Skip all postinstall scripts — node-llama-cpp tries to git clone in sandbox
  npmFlags = [ "--ignore-scripts" ];

  # Build TypeScript source → dist/
  npmBuildScript = "build";

  # Fix bin: upstream "qmd" is a bash wrapper that finds node, but the npm
  # hook wraps it with node (wrong). Replace with a direct node → dist/qmd.js wrapper.
  # Also rebuild better-sqlite3's native addon via node-gyp (npm rebuild would
  # re-trigger all scripts including node-llama-cpp).
  postInstall = ''
    pushd $out/lib/node_modules/@tobilu/qmd/node_modules/better-sqlite3
    ${nodejs_22}/bin/node ${nodejs_22}/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --release --nodedir=${nodejs_22}
    popd

    rm $out/bin/qmd
    cat > $out/bin/qmd <<'WRAPPER'
    #!/bin/sh
    export LD_LIBRARY_PATH="@ldLibraryPath@''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec @nodejs@/bin/node @out@/lib/node_modules/@tobilu/qmd/dist/qmd.js "$@"
    WRAPPER
    substituteInPlace $out/bin/qmd \
      --replace-fail '@ldLibraryPath@' "${lib.makeLibraryPath [ stdenv.cc.cc.lib stdenv.cc.libc vulkan-loader ]}" \
      --replace-fail '@nodejs@' "${nodejs_22}" \
      --replace-fail '@out@' "$out"
    chmod +x $out/bin/qmd
  '';

  meta = {
    description = "On-device hybrid search for markdown files with BM25, vector search, and LLM reranking";
    homepage = "https://github.com/jevy/qmd";
    license = lib.licenses.mit;
    mainProgram = "qmd";
  };
}
