# SparkSDR: Multi-platform SDR application with WSPR/FT8 decoding
# Proprietary .NET self-contained app using Avalonia UI + SkiaSharp
# Requires a display (real or virtual via xvfb-run) — no headless mode
# WebSocket control interface on port 4649
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  portaudio,
  libusb1,
  pipewire,
  fontconfig,
  zlib,
  openssl,
  icu,
  krb5,
  libx11,
  libxcursor,
  libxrandr,
  libxi,
  libice,
  libsm,
  libxext,
  libxrender,
  xvfb-run,
}:

stdenv.mkDerivation rec {
  pname = "sparksdr";
  version = "2.0.992";

  src = fetchurl {
    url = "https://www.sparksdr.com/download/SparkSDR.${version}.linux-x64.deb";
    hash = "sha256-W2nEHCJ7S2YMvDttqgsnkjhFmD1f9V4zRGLrNh7Kjro=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    portaudio
    libusb1
    pipewire
    fontconfig
    zlib
    openssl
    icu
    krb5
    stdenv.cc.cc.lib
    libx11
    libxcursor
    libxrandr
    libxi
    libice
    libsm
    libxext
    libxrender
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/SparkSDR $out/bin $out/lib/udev/rules.d

    cp -r usr/share/SparkSDR/* $out/share/SparkSDR/
    chmod +x $out/share/SparkSDR/SparkSDR

    # udev rules for Airspy devices (shipped in the .deb)
    cp -r etc/udev/rules.d/* $out/lib/udev/rules.d/ 2>/dev/null || true

    # Wrapper that can optionally run under xvfb for headless operation
    makeWrapper $out/share/SparkSDR/SparkSDR $out/bin/sparksdr \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    # Headless wrapper using xvfb-run (for systemd service)
    makeWrapper ${xvfb-run}/bin/xvfb-run $out/bin/sparksdr-headless \
      --add-flags "$out/share/SparkSDR/SparkSDR" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    runHook postInstall
  '';

  meta = {
    description = "Multi-platform SDR application with WSPR/FT8 decoding and PSKReporter integration";
    homepage = "https://www.sparksdr.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "sparksdr";
  };
}
