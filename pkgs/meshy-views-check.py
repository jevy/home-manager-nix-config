# Install check for pkgs/meshy.nix -- see the comment there.
#
# The views/ modules cannot go in pythonImportsCheck: their Gtk.Template
# decorators resolve resource paths at import time, and the gresource bundle is
# only registered by MeshyApplication at startup. Do what application.py does
# (register the bundle from pkgdatadir), then import them. This is what proves
# the Shumate typelib is actually reachable from the built package.
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Shumate", "1.0")
from gi.repository import Gio, Shumate  # noqa: F401

import meshy

meshy.pkgdatadir = sys.argv[1] + "/share/meshy"
meshy.QR_SCANNER_ENABLED = True
meshy.SHORTCUTS_DIALOG_ENABLED = True
Gio.resources_register(Gio.Resource.load(meshy.pkgdatadir + "/meshy.gresource"))

import meshy.views.map_view  # noqa: E402,F401
import meshy.views.contacts_view  # noqa: E402,F401
import meshy.views.repeater_view  # noqa: E402,F401

# qr_scanner.py wraps its pyzbar import in try/except and sets _pyzbar = None on
# failure, so a missing zbar degrades the scanner silently rather than raising.
# Assert it loaded, otherwise the build would happily ship a dead QR scanner.
import meshy.qr_scanner  # noqa: E402

assert meshy.qr_scanner._pyzbar is not None, "pyzbar/libzbar did not load"

# libshumate fetches its tiles over HTTPS through libsoup, which needs a GIO
# TLS backend (glib-networking). If that is missing the map renders blank with
# nothing on stderr, so assert it rather than trusting the map to look right.
tls = Gio.TlsBackend.get_default()
assert tls is not None and tls.supports_tls(), (
    "no GIO TLS backend: glib-networking missing from GIO_EXTRA_MODULES, "
    "map tiles would silently fail to load"
)

print("meshy: views import cleanly, Shumate resolved, pyzbar live, TLS backend present")
