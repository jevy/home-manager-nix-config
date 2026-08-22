# Shared overlays for all configurations
{ inputs, config, ... }:
{
  flake.overlays = {
    # MCP server packages from mcp-servers-nix
    mcpServers = inputs.mcp-servers-nix.overlays.default;

    # Build volsync kubectl plugin from source
    volsync = final: prev: {
      volsync = prev.buildGoModule rec {
        pname = "volsync";
        version = "0.14.0";
        src = prev.fetchFromGitHub {
          owner = "backube";
          repo = "volsync";
          rev = "v${version}";
          sha256 = "sha256-vtJlrqbuZ01wo3HRwfSY4RzR5uEKOmNKAmiHIj0CDIU=";
        };
        proxyVendor = true;
        vendorHash = "sha256-kv1HhjZYErO8aLmkMkrhOgEXFKijuc4Lj30UUZhatV8=";
        subPackages = [ "kubectl-volsync" ];
      };
    };

    # Bambu Studio AppImage — the nixpkgs build crashes on cloud login (#440951)
    bambuStudio = final: prev: {
      bambu-studio = prev.appimageTools.wrapType2 rec {
        name = "BambuStudio";
        pname = "bambu-studio";
        version = "02.05.02.51";

        src = prev.fetchurl {
          url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu-24.04_v${version}-20260327222803.AppImage";
          sha256 = "sha256-tWda80M3cV5hztEoYkZVGabQMgg6pyc/OniPJfghN0Q=";
        };

        profile = ''
          export SSL_CERT_FILE="${prev.cacert}/etc/ssl/certs/ca-bundle.crt"
          export GIO_MODULE_DIR="${prev.glib-networking}/lib/gio/modules/"
        '';

        extraPkgs = pkgs: with pkgs; [
          cacert
          glib
          glib-networking
          gst_all_1.gst-plugins-bad
          gst_all_1.gst-plugins-base
          gst_all_1.gst-plugins-good
          webkitgtk_4_1
        ];
      };
    };

    # goobook 3.5.2 pins simplejson<4.0.0 but nixpkgs ships 4.x; upstream
    # nixpkgs relaxes other deps but not this one (simplejson 4 dropped no
    # API goobook uses). TODO: drop once nixpkgs adds simplejson to
    # goobook's pythonRelaxDeps or goobook releases with the pin lifted.
    goobookRelaxDeps = final: prev: {
      goobook = prev.goobook.overridePythonAttrs (old: {
        pythonRelaxDeps = old.pythonRelaxDeps ++ [ "simplejson" ];
      });
    };

    # power-profiles-daemon 0.30's test suite is flaky in the Nix sandbox: its
    # python-dbusmock integration tests (test_vanishing_hold — which alone runs
    # ~60min before failing — plus ~12 others) time out/fail, breaking every
    # rebuild that pulls ppd in via udev-rules → system-path. Disable the whole
    # `tests` meson feature (nixpkgs auto-enables it because the build host can
    # execute the target, -Dtests=${canExecute}); that also drops the mandatory
    # UMockdev configure-time dependency the test build pulls in. Just doCheck=
    # false isn't enough — meson.build still requires UMockdev when tests are on.
    # TODO: drop once nixpkgs' ppd check phase passes again.
    powerProfilesDaemonSkipCheck = final: prev: {
      power-profiles-daemon = prev.power-profiles-daemon.overrideAttrs (old: {
        doCheck = false;
        mesonFlags =
          (builtins.filter
            (f: !(prev.lib.hasPrefix "-Dtests=" f))
            (old.mesonFlags or []))
          ++ [ "-Dtests=false" ];
      });
    };

    # Bundle the SDRplay backend into SoapySDR so any SoapySDR-based GUI
    # (CubicSDR, SDR++, SDRangel, gqrx, …) can drive the RSPdx via the
    # always-on sdrplay_apiService. Per upstream nixos services.sdrplayApi
    # docs.
    soapysdrSdrplay = final: prev: {
      soapysdr-with-plugins = prev.soapysdr.override {
        extraPackages = [ prev.soapysdrplay ];
      };
    };

    # ddcci-driver (out-of-tree DDC/CI kernel module, pulled in by
    # services.ddccontrol on the P14s) calls strncpy() in ddcci.c, but kernel
    # 7.2 removed strncpy from <linux/string.h> (in favour of strscpy), so the
    # module no longer compiles: GCC 15 hard-errors on the implicit
    # declaration. Swap the 5 strncpy(buf, device->X, PAGE_SIZE) calls to
    # strscpy() — semantically identical here (NUL-terminated copy into a
    # sysfs show buffer). Scope to linuxPackages_latest (7.2); older kernels
    # still ship strncpy. TODO: drop once nixpkgs bumps ddcci-driver to a rev
    # that's fixed upstream.
    ddcciDriverFix = final: prev: {
      linuxPackages_latest = prev.linuxPackages_latest.extend (self: super: {
        ddcci-driver = super.ddcci-driver.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace ./ddcci/ddcci.c \
              --replace-fail 'strncpy(buf, device->' 'strscpy(buf, device->'
          '';
        });
      });
    };

    # masterpdfeditor 5.9.98's tarball was removed from code-industry.net
    # (404), breaking the fetch. Pin src to 5.9.99, the oldest version the
    # vendor still hosts. The x86_64-only URL/hash is fine: the package's
    # `src` selects per-system, but our hosts are all x86_64-linux and this
    # is what the previous 5.9.98 hash covered. TODO: drop once nixpkgs bumps
    # masterpdfeditor past the deleted version.
    masterpdfeditorFix = final: prev: {
      masterpdfeditor = prev.masterpdfeditor.overrideAttrs (old: {
        version = "5.9.99";
        src = prev.fetchurl {
          url = "https://code-industry.net/public/master-pdf-editor-5.9.99-qt5.x86_64-qt_include.tar.gz";
          hash = "sha256-ksVuJyuImstESVwHUmOUv6aERosg6g5bSsRvPSf5EVM=";
        };
      });
    };

  };
}
