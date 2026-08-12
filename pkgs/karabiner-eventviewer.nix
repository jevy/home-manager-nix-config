# Karabiner-EventViewer on its own, carved out of the karabiner-elements
# package.
#
# EventViewer is a passive observer: it prints every key event macOS sees, with
# the raw HID usage page/usage, the macOS key code, and the modifier flags. That
# is exactly what is needed to map a custom keyboard layout onto AeroSpace's
# binding names (see modules/desktop/key-inspect.nix).
#
# WHY NOT JUST INSTALL karabiner-elements. The full package is 130 MB, of which
# EventViewer is 12 MB. The rest is Karabiner-Elements.app plus a Library tree
# of privileged daemons — Karabiner-Core-Service, "Privileged Daemons v2",
# "Non-Privileged Agents v2", an updater and a menu agent. Karabiner-Elements
# proper is a keyboard REMAPPER that wants a DriverKit virtual keyboard
# activated at the system level; launching it starts asking to install that
# extension. This host has no use for a second remapper — Caps→Control is
# already handled natively by system.keyboard in the mac-work host — and none of
# it can be activated by a Nix install anyway, since nix-darwin does not run the
# pkg installer those daemons expect.
#
# EventViewer needs none of it: `otool -L` shows it links nothing outside
# /usr/lib and /System, so it runs standalone against IOHIDManager.
#
# dontFixup is essential. The default fixup phase strips binaries and rewrites
# install names, either of which invalidates the bundle's code signature — and
# an app with a broken signature cannot be granted Input Monitoring, which is
# the one permission this app exists to use. A plain recursive copy keeps the
# bytes, and therefore the signature, intact.
{
  lib,
  stdenvNoCC,
  karabiner-elements,
}:
stdenvNoCC.mkDerivation {
  pname = "karabiner-eventviewer";
  inherit (karabiner-elements) version;

  dontUnpack = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R "${karabiner-elements}/Applications/Karabiner-EventViewer.app" "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Karabiner-EventViewer — inspect raw macOS key events";
    longDescription = ''
      Shows every key event macOS observes, including the HID usage page and
      usage, the macOS key code name, and the modifier flags. Useful for
      discovering what a custom keyboard layout or programmable keyboard
      actually sends, without installing the Karabiner-Elements remapper or its
      DriverKit extension.

      Needs Input Monitoring permission (System Settings -> Privacy & Security
      -> Input Monitoring), granted once by hand on first launch.
    '';
    homepage = "https://karabiner-elements.pqrs.org/docs/manual/operation/eventviewer/";
    license = lib.licenses.unlicense;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "Karabiner-EventViewer";
  };
}
