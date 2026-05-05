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
  libglvnd,
  mesa,
  sdrplay,
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
    libglvnd       # libGL.so.1, libEGL.so.1 dispatch (SkiaSharp dlopen target)
    mesa           # software OpenGL (llvmpipe DRI driver) for headless / Xvnc
    sdrplay        # libsdrplay_api.so.3 — sparkcore.so dlopens it for RSP devices
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/SparkSDR $out/bin $out/lib/udev/rules.d

    cp -r usr/share/SparkSDR/* $out/share/SparkSDR/
    chmod +x $out/share/SparkSDR/SparkSDR

    # The shipped libpipewireaudioprovider.so segfaults at PipeWire device
    # enumeration ("enum loop" → SIGSEGV) — its build-time PipeWire ABI
    # doesn't match nixpkgs's libpipewire-0.3 even after autoPatchelfHook
    # rewrites NEEDED entries. Removing it makes SparkSDR fall back to ALSA,
    # which on a PipeWire-enabled host goes through PipeWire's ALSA emulation
    # anyway (so the IC-7300 USB codec is still reachable, no audio lost).
    rm $out/share/SparkSDR/libpipewireaudioprovider.so

    # udev rules for Airspy devices (shipped in the .deb)
    cp -r etc/udev/rules.d/* $out/lib/udev/rules.d/ 2>/dev/null || true

    # Desktop entry so it shows up in app menus
    mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
    if [ -f usr/share/SparkSDR/Assets/icon.png ]; then
      cp usr/share/SparkSDR/Assets/icon.png $out/share/icons/hicolor/256x256/apps/sparksdr.png
    fi
    {
      echo "[Desktop Entry]"
      echo "Type=Application"
      echo "Name=SparkSDR"
      echo "Comment=Multi-platform SDR with WSPR/FT8 decoding"
      echo "Exec=$out/bin/sparksdr"
      echo "Icon=sparksdr"
      echo "Categories=HamRadio;AudioVideo;Network;"
      echo "Terminal=false"
    } > $out/share/applications/sparksdr.desktop

    # Force software (llvmpipe) GL — SkiaSharp picks GPU when libGL is
    # available, but on a headless box (no /dev/dri, Xvnc with no GLX
    # backend) GPU init hangs. llvmpipe is fine for the splash + a
    # static UI; decoding is CPU anyway.
    # SparkSDR also dlopens sibling .so's by bare name (sparkcore.so etc),
    # so the app dir needs to be on LD_LIBRARY_PATH.
    glWrap=(
      --prefix LD_LIBRARY_PATH : "$out/share/SparkSDR"
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"
      --set LIBGL_DRIVERS_PATH "${mesa}/lib/dri"
      --set LIBGL_ALWAYS_SOFTWARE 1
    )

    # GUI wrapper (real or forwarded display)
    makeWrapper $out/share/SparkSDR/SparkSDR $out/bin/sparksdr "''${glWrap[@]}"

    # Headless wrapper using xvfb-run (for systemd service)
    makeWrapper ${xvfb-run}/bin/xvfb-run $out/bin/sparksdr-headless \
      --add-flags "$out/share/SparkSDR/SparkSDR" \
      "''${glWrap[@]}"

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
