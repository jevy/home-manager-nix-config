# Audio configuration (PipeWire, Bluetooth)
{ ... }:
{
  # NixOS audio configuration
  flake.modules.nixos.audio =
    { pkgs, ... }:
    {
      hardware.bluetooth.enable = true;

      # BlueZ 5.86 regression: dual-role devices (e.g. Bose QC45, which
      # advertises both Audio Source and Audio Sink) only expose the reversed
      # "audio-gateway" profile — the A2DP Sink profile never registers, so
      # playback fails with "a2dp-sink profile connect failed: Device or
      # resource busy". Fixed upstream in 5.87 (bluez#1922, fix 066a164a).
      #
      # Pinned HERE (daemon only) rather than as a global overlay on purpose:
      # bluez sits under pipewire/gst-plugins-bad, so overlaying it globally
      # invalidates the binary cache for wine, chromium, qtwebengine, and
      # ~100 other packages. The fix is in bluetoothd's profile registration,
      # so only the daemon needs 5.87; everything else keeps linking cached
      # 5.86 client libs (D-Bus API is stable across the two).
      # TODO: drop once nixpkgs ships bluez >= 5.87 (still 5.86 as of
      # 2026-07-29 nixos-unstable).
      # If the QC45 still misbehaves on 5.87, suspect WirePlumber role
      # negotiation (wireplumber#969 / bluez#2280), not BlueZ.
      # https://github.com/bluez/bluez/issues/1922
      hardware.bluetooth.package = pkgs.bluez.overrideAttrs (old: {
        version = "5.87";
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/bluetooth/bluez-5.87.tar.xz";
          hash = "sha256-Jr3PLOvXMQxvWYhQYGsDfvDFFf5mCOvFTSLFDEwys18=";
        };
        # nixpkgs' bluez patches are all tuned for 5.86: the btctl regression
        # fixes and libical-4.0 support are already upstream in 5.87 (apply
        # reversed), and lreadline.patch's Makefile.tools hunks don't match.
        # 5.87 builds clean without them (verified 2026-07-27).
        patches = [ ];
      });
      services.blueman.enable = true;

      services.pulseaudio = {
        enable = false;
        daemon.config = {
          flat-volumes = "no";
        };
      };

      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        pulse.enable = true;
        jack.enable = true;
      };

      # Set Intel HDA card to expose both HDMI and analog outputs
      # This makes the Dell U4924DW monitor speakers available as a sink
      services.pipewire.wireplumber.extraConfig."50-hdmi-profile" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "device.name" = "alsa_card.pci-0000_00_1f.3"; }
            ];
            actions = {
              update-props = {
                "api.acp.auto-profile" = false;
                "device.profile" = "output:hdmi-stereo+input:analog-stereo";
              };
            };
          }
        ];
      };

      # Pin LDAC to 990 kbps instead of the default adaptive bitrate, which
      # sags under marginal RF even when the link could sustain full rate.
      # Drop to "sq" (660 kbps) if dropouts show up.
      services.pipewire.wireplumber.extraConfig."52-ldac-hq" = {
        "monitor.bluez.rules" = [
          {
            matches = [
              { "device.name" = "~bluez_card.*"; }
            ];
            actions = {
              update-props = {
                "bluez5.a2dp.ldac.quality" = "hq";
              };
            };
          }
        ];
      };

      # Audio device priority configuration
      # Scarlett > QC35 Bluetooth > Laptop speakers (fallback)
      services.pipewire.wireplumber.extraConfig."51-device-priorities" = {
        # Scarlett USB Audio Interface - highest priority
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_output.usb-Focusrite.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2000;
                "priority.session" = 1400;
              };
            };
          }
          {
            matches = [
              { "node.name" = "~alsa_input.usb-Focusrite.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2500;
                "priority.session" = 2500;
              };
            };
          }
        ];

        # QC35 Bluetooth headphones - second priority
        "monitor.bluez.rules" = [
          {
            matches = [
              { "node.name" = "~bluez_output.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 1800;
                "priority.session" = 1200;
              };
            };
          }
          {
            matches = [
              { "node.name" = "~bluez_input.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2200;
                "priority.session" = 2200;
              };
            };
          }
        ];
      };
    };

  # Home-manager audio services
  flake.modules.homeManager.audio =
    { ... }:
    {
      services.playerctld.enable = true;
    };
}
