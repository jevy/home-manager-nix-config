# Shop SDR station: DeskMini running IC-7300 + SDRplay RSPduo
# WSPR beaconing, remote rig control via wfview over Tailscale
#
# ── Hardware ──────────────────────────────────────────────────────────
#   - ASRock DeskMini (x86_64, 8GB RAM, 1TB SATA SSD at /dev/sda)
#   - Icom IC-7300 (USB-B → DeskMini: CI-V serial + audio codec)
#   - SDRplay RSPduo (USB → DeskMini: dual-tuner SDR)
#   - Antenna via IC-7300 SDR mod
#
# ── Initial NixOS Install (nixos-anywhere) ───────────────────────────
#
#   1. Boot the Ubuntu live CD (or any Linux) on the DeskMini
#   2. Get SSH running and note the IP:
#        sudo systemctl start ssh
#        ip a   # note the IP, e.g. 192.168.1.163
#   3. Set a temporary root password on the DeskMini:
#        sudo passwd root
#   4. From your laptop, run nixos-anywhere:
#        nix run github:nix-community/nixos-anywhere -- \
#          --flake '.#shop-sdr' root@<deskmini-ip> --build-on-remote
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
#
# ── Secrets ───────────────────────────────��───────────────────────────
#
#   Copy your age key to the DeskMini so sops-nix can decrypt secrets:
#     scp ~/.config/sops/age/keys.txt jevin@shop-sdr:~/.config/sops/age/keys.txt
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
# ── Enabling Services ────────────────────────────────────────────────
#
#   Services in modules/services/ham-radio.nix are commented out until
#   hardware is connected. Once the IC-7300 and RSPduo are plugged in:
#
#   1. Verify udev created the symlinks:
#        ls -la /dev/ic7300       # IC-7300 serial
#        arecord -l               # IC-7300 USB audio should appear
#
#   2. Uncomment services in ham-radio.nix one at a time:
#        - rigctld (IC-7300 CAT control on :4532)
#        - wfserver (remote rig control + audio on :4533)
#        - sparksdr (RSPduo WSPR skimmer, WebSocket on :4649)
#
#   3. Redeploy: nix run .#deploy -- .#shop-sdr
#
# ── Remote Rig Control ───────────────────────────────────────────────
#
#   Once wfserver is running, connect from your laptop:
#     wfview → Settings → Server → shop-sdr:50740 (default wfserver port)
#
#   WSJT-X (remote): point rigctld at shop-sdr:4533 (wfview's rigctld emulation)
#   SparkSDR WebSocket: ws://shop-sdr:4649
#
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos;
in
{
  configurations.nixos."shop-sdr".module =
    { pkgs, lib, ... }:
    {
      imports = [
        # Disk partitioning (used by nixos-anywhere for initial install)
        inputs.disko.nixosModules.disko

        # Hardware (replace placeholder after running nixos-generate-config on DeskMini)
        ../../../nixos/shop-sdr-hardware-configuration.nix

        # Headless server base (nix, user, zsh, tailscale, network, ssh, home-manager)
        nixos.linuxServerBase

        # Ham radio stack (SDRplay API, wfview, hamlib, WSJT-X, SparkSDR)
        nixos.hamRadio
      ];

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

      # PipeWire for audio routing (IC-7300 USB audio codec + SparkSDR)
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };
      # Disable PulseAudio (PipeWire replaces it)
      services.pulseaudio.enable = false;
    };
}
