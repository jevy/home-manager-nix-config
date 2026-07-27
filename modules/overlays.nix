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

    # Patched lieer: save state after metadata phase so interrupted full pulls
    lieer = final: prev: {
      lieer = prev.lieer.overrideAttrs (old: {
        src = inputs.lieer-src;
        patches = [];
      });
    };

    # BlueZ 5.86 regression: dual-role devices (e.g. Bose QC45, which advertises
    # both Audio Source and Audio Sink) only expose the reversed "audio-gateway"
    # profile — the A2DP Sink profile never registers, so playback fails with
    # "a2dp-sink profile connect failed: Device or resource busy".
    # Fixed upstream in 5.87 (bluez#1922, closed 2026-05-24; fix 066a164a is in
    # the 5.87 tag — the earlier "5.87 does not fix it" note here was wrong).
    # nixpkgs still ships 5.86, so pin 5.87 forward instead of 5.85 back.
    # TODO: delete this overlay once nixpkgs ships bluez >= 5.87.
    # If the QC45 still misbehaves on 5.87, suspect WirePlumber role
    # negotiation (wireplumber#969 / bluez#2280), not BlueZ.
    # https://github.com/bluez/bluez/issues/1922
    bluezPin = final: prev: {
      bluez = prev.bluez.overrideAttrs (old: {
        version = "5.87";
        src = prev.fetchurl {
          url = "mirror://kernel/linux/bluetooth/bluez-5.87.tar.xz";
          hash = "sha256-Jr3PLOvXMQxvWYhQYGsDfvDFFf5mCOvFTSLFDEwys18=";
        };
        # nixpkgs' bluez patches are all tuned for 5.86: the btctl regression
        # fixes and libical-4.0 support are already upstream in 5.87 (apply
        # reversed), and lreadline.patch's Makefile.tools hunks don't match.
        # 5.87 builds clean without them (verified 2026-07-27).
        patches = [ ];
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

  };
}
