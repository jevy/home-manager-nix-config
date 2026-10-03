# gruvbox-art: tint a base16 scheme (gruvbox) toward a painting, deterministically.
# See the docstring in gruvbox_art.py for what moves and what stays fixed.
#
#   gruvbox-art painting.jpg > scheme.yaml
#   gruvbox-art painting.jpg --strength 1 --preview preview.png
#
# `scheme` is the same thing as a derivation, for feeding stylix at build time:
#   stylix.base16Scheme = (pkgs.callPackage ./pkgs/gruvbox-art { }).scheme image;
{
  lib,
  python3Packages,
  writers,
  runCommand,
  base16-schemes,
  dejavu_fonts,
  base ? "${base16-schemes}/share/themes/gruvbox-material-dark-soft.yaml",
  strength ? 0.6,
}:
let
  bin = writers.writePython3Bin "gruvbox-art" {
    libraries = [ python3Packages.pillow ];
    flakeIgnore = [
      "E501"
      "E741"
      "E203"
    ];
  } (builtins.readFile ./gruvbox_art.py);

  # Bakes in the base scheme and font so callers only pass an image.
  wrapped = runCommand "gruvbox-art" { } ''
    mkdir -p $out/bin
    cat > $out/bin/gruvbox-art <<EOF
    #!/bin/sh
    export GRUVBOX_ART_FONT=${dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf
    exec ${bin}/bin/gruvbox-art --base ${base} --strength ${toString strength} "\$@"
    EOF
    chmod +x $out/bin/gruvbox-art
  '';
in
wrapped.overrideAttrs (old: {
  passthru = {
    scheme =
      image:
      runCommand "gruvbox-art-scheme.yaml" { } ''
        ${bin}/bin/gruvbox-art ${image} --base ${base} --strength ${toString strength} > $out
      '';
  };
  meta.mainProgram = "gruvbox-art";
})
