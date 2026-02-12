{ pkgs, width ? 3840, height ? 2160, seed ? "gruvbox42", cellSize ? 150 }:

let
  nodeModules = pkgs.buildNpmPackage {
    pname = "lowpoly-wallpaper";
    version = "1.0.0";
    src = ./.;
    npmDepsHash = "sha256-OnmhHv24Sg1JYBOSNLyKbR+BKOFARXjt4JiNT1QOhok=";
    dontNpmBuild = true;
    npmFlags = [ "--ignore-scripts" ];
    postPatch = ''
      # Stub out the native canvas dependency — we only use SVG output
      mkdir -p canvas-stub
      echo 'module.exports = {};' > canvas-stub/index.js
    '';
    installPhase = ''
      mkdir -p $out/lib/node_modules
      cp -r node_modules/* $out/lib/node_modules/
      # Replace the native canvas module with our stub
      rm -rf $out/lib/node_modules/canvas
      cp -r canvas-stub $out/lib/node_modules/canvas
      cp generate.mjs $out/lib/
    '';
  };
in
pkgs.runCommand "lowpoly-wallpaper.png" {
  nativeBuildInputs = [ pkgs.nodejs pkgs.librsvg ];
} ''
  export NODE_PATH=${nodeModules}/lib/node_modules
  node ${nodeModules}/lib/generate.mjs wallpaper.svg ${toString width} ${toString height} ${seed} ${toString cellSize}
  rsvg-convert -w ${toString width} -h ${toString height} wallpaper.svg -o $out
''
