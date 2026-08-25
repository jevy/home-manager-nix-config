# MonoMic.app — a minimal application bundle whose only job is to hold a
# microphone permission.
#
# It contains no UI and no audio code. The bundle exists because macOS TCC can
# only attach a Microphone grant to something it can identify and list: an .app
# with an Info.plist, a bundle identifier, and a code signature. The bridge
# itself stays in Nix, outside the bundle, and is named by a config file the
# shim reads at startup — see pkgs/mono-mic-app/shim.c for why that separation
# is what makes the grant survive a rebuild.
#
# The signing is deliberately NOT done here. Signing happens once in the
# nix-darwin activation script (modules/services/mono-mic.nix), against the copy
# in /Applications, using /usr/bin/codesign — nixpkgs' sigtool is a partial
# reimplementation that does not seal bundle resources, and TCC needs a real
# bundle signature.
#
# dontFixup is essential, for the same reason it is in
# pkgs/karabiner-eventviewer.nix: the default fixup phase strips binaries and
# rewrites install names. Either would change the shim's bytes, and therefore
# its cdhash, and therefore invalidate the very grant this bundle exists to
# hold.
{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "mono-mic-app";
  version = "1.0";

  srcs = [
    ./shim.c
    ./Info.plist
  ];

  dontUnpack = true;
  dontFixup = true;

  buildPhase = ''
    runHook preBuild
    # -O2 with no libraries beyond libSystem: nothing to strip, nothing to
    # rewrite, and no store path lands in the output.
    $CC -O2 -Wall -Wextra -o mono-mic ${./shim.c}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    app="$out/Applications/MonoMic.app"
    mkdir -p "$app/Contents/MacOS"
    cp ${./Info.plist} "$app/Contents/Info.plist"
    cp mono-mic "$app/Contents/MacOS/mono-mic"
    chmod +x "$app/Contents/MacOS/mono-mic"
    runHook postInstall
  '';

  meta = {
    description = "Application bundle that holds the microphone grant for the mono-mic bridge";
    longDescription = ''
      A bundle with no interface. Its main executable is a small Mach-O shim
      that reads a command from
      ~/Library/Application Support/mono-mic/command, forks, and runs it,
      staying alive as the parent so the child inherits the bundle as its TCC
      responsible process.

      Needs Microphone permission (System Settings -> Privacy & Security ->
      Microphone), granted once by hand. Nothing about the grant is declarable
      from Nix.
    '';
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "mono-mic";
  };
}
