# Meshy: GTK4/libadwaita desktop client for MeshCore LoRa mesh radios.
#
# Not in nixpkgs (checked 2026-09-24) -- upstream ships Flatpak/Flathub only.
# This is a straight meson build of the Codeberg tag.
#
# Transports: BLE via BlueZ over GDBus (platforms/linux/ble_bluez.py -- no
# bleak, nothing to add), USB serial via pyserial, and TCP/WiFi. The serial
# path needs the uaccess udev rules upstream ships in
# data/linux/60-meshy-serial.rules; modules/apps/meshcore.nix installs them.
#
# Maps are libshumate, so the Shumate typelib has to be on GI_TYPELIB_PATH --
# gi.require_version("Shumate", "1.0") is a hard import in views/map_view.py
# and views/contacts_view.py, not a lazy one, so a missing typelib is a crash
# on startup rather than a degraded map.
{
  lib,
  python3,
  fetchFromGitea,
  meson,
  ninja,
  pkg-config,
  gettext,
  glib,
  desktop-file-utils,
  gobject-introspection,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
  libshumate,
  librsvg,
  zbar,
  glib-networking,
  gst_all_1,
  pipewire,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "meshy";
  version = "26.09";
  format = "other";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "sesivany";
    repo = "Meshy";
    rev = version;
    hash = "sha256-U23MuusLKePra/qe+J1Co7aeIwmVmKTegE8BM8j4md4=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    gettext
    glib # glib-compile-schemas / glib-compile-resources
    desktop-file-utils
    gobject-introspection
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    libadwaita
    libshumate # map view
    librsvg # symbolic icons

    # GIO's TLS backend. Without it libsoup cannot do HTTPS, so libshumate's
    # tile fetches fail and the map view renders blank with no error on stderr
    # -- the map just stays empty. wrapGAppsHook4 only contributes dconf to
    # GIO_EXTRA_MODULES, so this has to be an explicit buildInput.
    glib-networking
    zbar # pyzbar loads libzbar via ctypes

    # QR scanning (src/qr_scanner.py): XDG camera portal -> PipeWire ->
    # GStreamer. The elements it builds by name are queue/tee/capsfilter
    # (core), videoconvert/decodebin3/appsink (base), gtk4paintablesink
    # (plugins-rs), and the portal hands over a pipewiresrc. The gstreamer
    # setup hook folds each of these into GST_PLUGIN_SYSTEM_PATH_1_0, which
    # wrapGAppsHook4 then bakes into the launcher.
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-rs
    pipewire
  ];

  propagatedBuildInputs = with python3.pkgs; [
    pygobject3
    pycryptodome # mesh_crypto.py
    pyserial # usb_serial.py
    msgpack # meshcore_packets.py
    segno # QR generation (share your contact)
    pyzbar # QR scanning (meson option qr_scanner, on by default)
  ];

  # wrapGAppsHook4 and wrapPythonPrograms would otherwise both wrap the
  # launcher; let the Python hook do it and fold the GApps env in.
  dontWrapGApps = true;
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  # `meshy --help` only reaches application.py, so on its own it proves nothing
  # about the lazily-imported leaves. These pull in Gst (qr_scanner),
  # pycryptodome, pyserial and msgpack -- the deps most likely to go silently
  # missing when a GNOME-runtime Flatpak is rebuilt against nixpkgs.
  pythonImportsCheck = [
    "meshy"
    "meshy.mesh_crypto"
    "meshy.meshcore_packets"
    "meshy.usb_serial"
    "meshy.qr_scanner" # Gst + the portal camera pipeline
  ];

  # The views/ modules cannot go in pythonImportsCheck: their Gtk.Template
  # decorators resolve resource paths at import time, and the gresource bundle
  # is only registered by MeshyApplication at startup. Register it first, the
  # same way application.py does, then import them -- this is what actually
  # proves the Shumate typelib is reachable.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # buildInputs do not populate GIO_EXTRA_MODULES for the build env (only the
    # wrapper gets it), so point the check at the TLS backend explicitly. That
    # proves glib-networking works, but not that we shipped it -- so also assert
    # the generated launcher actually wires it in.
    GIO_EXTRA_MODULES="${glib-networking}/lib/gio/modules" \
    PYTHONPATH="$out/${python3.sitePackages}:$PYTHONPATH" \
      ${python3.interpreter} ${./meshy-views-check.py} "$out"

    if ! grep -q glib-networking $out/bin/meshy; then
      echo "ERROR: launcher does not reference glib-networking;" \
           "GIO would have no TLS backend and map tiles would silently fail" >&2
      exit 1
    fi
    echo "meshy: launcher wires glib-networking into GIO_EXTRA_MODULES"

    runHook postInstallCheck
  '';

  meta = {
    description = "GTK4/libadwaita client for MeshCore LoRa mesh networks";
    homepage = "https://meshy-app.org/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "meshy";
    platforms = lib.platforms.linux;
  };
}
