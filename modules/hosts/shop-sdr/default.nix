# Shop SDR station: Dell OptiPlex 5070 running IC-7300 + SDRplay RSPdx
# WSPR beaconing, remote rig control over Tailscale
#
# ── Hardware ──────────────────────────────────────────────────────────
#   - Dell OptiPlex 5070 (i5-9500 Coffee Lake, 8GB RAM, 1TB SATA SSD at /dev/sda)
#   - Icom IC-7300 (USB-B → OptiPlex: CI-V serial + audio codec)
#   - SDRplay RSPdx (USB → OptiPlex: 1 kHz – 2 GHz wideband SDR, vendor:product 1df7:3030)
#   - Antenna via IC-7300 SDR mod (RX-OUT → RSPdx ANT C)
#
# ── Initial NixOS Install (nixos-anywhere) ───────────────────────────
#
#   1. Boot the Ubuntu live CD (or any Linux) on the OptiPlex
#   2. Get SSH running and note the IP:
#        sudo systemctl start ssh
#        ip a   # note the IP, e.g. 192.168.1.163
#   3. Set a temporary root password on the OptiPlex:
#        sudo passwd root
#   4. From your laptop, run nixos-anywhere:
#        nix run github:nix-community/nixos-anywhere -- \
#          --flake '.#shop-sdr' root@<optiplex-ip> --build-on-remote
#
#   nixos-anywhere will kexec into a NixOS installer, partition the disk
#   via disko (/dev/sda → 512M ESP + ext4 root), and install the config
#   all over SSH. The live CD is just a bootstrap to get SSH access.
#   It wipes the disk regardless.
#
#   To re-install from scratch, just boot the live CD again and repeat.
#
#   After install, update the hardware config with actual scan output:
#     ssh jevin@shop-sdr
#     nixos-generate-config --root / --dir /tmp/hw
#     # Copy the kernel module lines from /tmp/hw/hardware-configuration.nix
#     # into nixos/shop-sdr-hardware-configuration.nix
#     # (filesystems are managed by disko — don't copy those)
#     # (CPU/GPU hardware profiles are handled by nixos-hardware imports below)
#
# ── Secrets ───────────────────────────────��───────────────────────────
#
#   Copy your age key to the DeskMini so sops-nix can decrypt secrets:
#     scp ~/.config/sops/age/keys.txt jevin@shop-sdr:.config/sops/age/keys.txt
#
# ── Tailscale ─────────────────────────────────────────────────────────
#
#   On first boot, join your tailnet:
#     ssh jevin@<deskmini-lan-ip>
#     sudo tailscale up
#
#   After this, the machine is reachable as "shop-sdr" over Tailscale.
#
# ── Deploying (ongoing) ──────────────────────────────────────────────
#
#   From your laptop, push config changes with deploy-rs:
#     nix run .#deploy -- .#shop-sdr
#
#   deploy-rs has magic rollback: if the deploy breaks SSH connectivity,
#   the DeskMini automatically reverts to the previous config within 30s.
#
#   Alternatively, deploy from the DeskMini itself:
#     sudo nixos-rebuild switch --flake "github:jevy/nixpkgs#shop-sdr"
#
# ── Services (modules/services/ham-radio.nix) ────────────────────────
#
#   - sdrplayApi      system unit, always-on, owns the RSPdx over USB
#   - rigctld         system unit, always-on, /dev/ic7300, hamlib on :4532
#   - sdrpp-server    user unit, manual start (RSPdx single-tuner)
#   - sdrangel-server user unit, manual start (RSPdx single-tuner)
#
#   Verify hardware:
#     ls -la /dev/ic7300       # IC-7300 serial symlink
#     arecord -l               # IC-7300 USB audio codec should appear
#     systemctl status sdrplayApi
#
# ── Operating SparkSDR ──────────────────────────────────────────────
#
#   SparkSDR is interactive-only — launched from the RDP session and
#   left running there. xrdp-sesman keeps the X session alive across
#   disconnect, so SparkSDR keeps spotting / WSPR-ing while the Remmina
#   window is closed. Workflow:
#
#     1. Set jevin's Linux password (one-time, for RDP auth):
#          ssh shop-sdr 'sudo passwd jevin'
#     2. RDP in (Remmina / Microsoft Remote Desktop / FreeRDP):
#          shop-sdr:3389  → log in as jevin, lands in XFCE
#     3. Launch SparkSDR from the Applications menu (first run: pick
#        the RSPdx, ANT C, enable WSPR/FT8 bands, set callsign + grid,
#        enable PSKReporter upload — settings persist in
#        ~/.config/m0nnb/SparkSDR2/).
#     4. Close the Remmina window — session + SparkSDR stay running.
#        Reconnect any time to peek at decodes.
#
# ── Playing with other SDR apps ──────────────────────────────────────
#
#   The RSPdx is single-tuner — only one process can own it. To run
#   sdrpp-server or sdrangel-server, quit SparkSDR first (in the RDP
#   session) then:
#
#     systemctl --user start sdrpp-server    # then sdrpp on laptop → shop-sdr:5259
#     systemctl --user start sdrangel-server # then http://shop-sdr:8091/
#
# ── Remote access ────────────────────────────────────────────────────
#
#   rigctld (CAT):       hamlib NET rigctl model 2 → shop-sdr:4532
#   SparkSDR WebSocket:  ws://shop-sdr:4649
#   SDR++ IQ server:     shop-sdr:5259  (sdrpp client on laptop)
#   SDRangel web UI:     http://shop-sdr:8091/
#
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
  inherit (config.flake) overlays;
in
{
  configurations.nixos."shop-sdr".module =
    { pkgs, lib, ... }:
    {
      imports = [
        # Disk partitioning (used by nixos-anywhere for initial install)
        inputs.disko.nixosModules.disko

        # Hardware — nixos-hardware profiles for OptiPlex 5070 (Coffee Lake i5-9500 + UHD 630 iGPU)
        inputs.nixos-hardware.nixosModules.common-cpu-intel
        inputs.nixos-hardware.nixosModules.common-gpu-intel  # i915 + hardware.graphics + intel-media-driver
        inputs.nixos-hardware.nixosModules.common-pc
        inputs.nixos-hardware.nixosModules.common-pc-ssd
        ../../../nixos/shop-sdr-hardware-configuration.nix

        # Headless server base (nix, user, zsh, tailscale, network, ssh, home-manager)
        nixos.linuxServerBase

        # Ham radio stack (SDRplay API, wfview, hamlib, WSJT-X, SparkSDR)
        nixos.hamRadio

        # XFCE auto-started at boot + xrdp on :3389 — RDP into shop-sdr
        nixos.remoteDesktop

        # WaveLogGate — push CAT data from rigctld to Wavelog
        nixos.wlgate

        # GridTracker — live WSJT-X decode map
        nixos.gridtracker
      ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # Bundles SDRplay plugin into soapysdr-with-plugins so any
      # SoapySDR-backed app (CubicSDR, SDR++, SDRangel, gqrx) sees the RSPdx.
      nixpkgs.overlays = [ overlays.soapysdrSdrplay ];

      # Disk layout for nixos-anywhere — simple single-disk GPT + ext4
      # Change /dev/sda to match your actual disk (check with `lsblk`)
      disko.devices.disk.main = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0022" "dmask=0022" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };

      networking.hostName = "shop-sdr";

      # Hardware OpenGL — paired with nixos-hardware.common-gpu-intel above.
      # Provides /run/opengl-driver/lib/dri so SkiaSharp/Avalonia (SparkSDR,
      # SDR++, SDRangel) and Xvnc GLX can find mesa drivers.
      hardware.graphics.enable = true;

      # Defer dbus-broker migration — nixpkgs flipped the default and the
      # switch inhibitor blocks live activation. Stay on legacy dbus until
      # we plan a reboot to flip to broker.
      services.dbus.implementation = "dbus";

      # PipeWire for audio routing (IC-7300 USB audio codec + SparkSDR).
      # jack.enable provides the libjack shim so fldigi (and other JACK-first
      # ham apps) connect to PipeWire instead of failing on a missing jackd.
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
        jack.enable = true;
      };
      # Disable PulseAudio (PipeWire replaces it)
      services.pulseaudio.enable = false;
    };
}
