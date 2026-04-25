# WaveLogGate: bridges flrig/rigctld CAT data to Wavelog REST API
# Wails v2 Go app with webkitgtk UI — needs xvfb-run for headless operation
# https://github.com/wavelog/WaveLogGate
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  webkitgtk_4_1,
  gtk3,
  glib,
  gdk-pixbuf,
  libsoup_3,
  xvfb-run,
}:

stdenv.mkDerivation rec {
  pname = "waveloggate";
  version = "2.0.2";

  src = fetchurl {
    url = "https://github.com/wavelog/WaveLogGate/releases/download/v${version}/wavelog-gate_${version}_webkit4.1_amd64.deb";
    hash = "sha256-yXzpd0aij+QEZJc9KXJEQViqxBs9hyOqurW4gpzUSlA=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    glib
    gdk-pixbuf
    libsoup_3
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp usr/local/bin/wavelog-gate $out/bin/wavelog-gate-unwrapped
    chmod +x $out/bin/wavelog-gate-unwrapped

    # GUI wrapper
    makeWrapper $out/bin/wavelog-gate-unwrapped $out/bin/wavelog-gate \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    # Headless wrapper using xvfb-run (for systemd service)
    makeWrapper ${xvfb-run}/bin/xvfb-run $out/bin/wavelog-gate-headless \
      --add-flags "$out/bin/wavelog-gate-unwrapped" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    runHook postInstall
  '';

  meta = {
    description = "Bridge flrig/rigctld CAT data to Wavelog logging platform";
    homepage = "https://github.com/wavelog/WaveLogGate";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "wavelog-gate";
  };
}
