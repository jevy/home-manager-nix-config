# Lenovo ThinkPad P14s Gen 6 AMD — NixOS Setup Guide

## Prerequisites

- USB drive with NixOS minimal ISO (download from nixos.org)
- This repo cloned or accessible (e.g., on another machine or USB)

## 1. Boot the NixOS Installer

1. Insert the NixOS USB and boot from it (F12 for boot menu on ThinkPads)
2. In BIOS (F1), ensure Secure Boot is **disabled** (NixOS doesn't support it by default)
3. You'll land in a root shell on the minimal ISO

## 2. Partition the Disk

The P14s has a single NVMe drive. This layout uses LUKS encryption with Btrfs subvolumes.

```bash
# Identify the NVMe drive
lsblk

# Partition: 512MB EFI + rest for LUKS
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 512MiB 100%

# Format EFI partition
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1

# Set up LUKS encryption on the main partition
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot

# Create Btrfs filesystem with subvolumes
mkfs.btrfs -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

# Mount subvolumes
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,boot}
mount -o subvol=@home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/cryptroot /mnt/nix
mount /dev/nvme0n1p1 /mnt/boot
```

## 3. Generate Hardware Configuration

This is the critical step — it detects your actual hardware and generates the correct `hardware-configuration.nix`.

```bash
nixos-generate-config --root /mnt
```

This creates two files in `/mnt/etc/nixos/`:
- `configuration.nix` — we won't use this (our flake replaces it)
- `hardware-configuration.nix` — **this is what we need**

## 4. Copy Hardware Config into This Repo

Copy the generated file to replace the placeholder:

```bash
# If the repo is on a USB drive mounted at /mnt2:
cp /mnt/etc/nixos/hardware-configuration.nix /mnt2/path-to-repo/nixos/lenovo-p14s-hardware-configuration.nix

# Or just cat it and copy manually:
cat /mnt/etc/nixos/hardware-configuration.nix
```

**Important**: The generated file will have the correct:
- LUKS device UUID (not `/dev/nvme0n1p1` — it uses `/dev/disk/by-uuid/...`)
- Btrfs subvolume mount options
- Detected kernel modules for your specific hardware
- CPU microcode settings

## 5. Update the LUKS Device in the Host Config

The generated `hardware-configuration.nix` will contain the actual LUKS device path. You also need to update `modules/hosts/lenovo-p14s/default.nix` to match.

Open the generated file and find the `boot.initrd.luks.devices` section. It will look something like:

```nix
boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-uuid/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
```

Update `modules/hosts/lenovo-p14s/default.nix` — change the placeholder LUKS block to match:

```nix
boot.initrd.luks.devices.cryptroot = {
  device = "/dev/disk/by-uuid/YOUR-ACTUAL-UUID-HERE";
};
```

(Remove the `preLVM = true` line — that's a ZFS/LVM thing from the framework config, not needed for plain LUKS+Btrfs.)

## 6. Install NixOS

```bash
# Connect to wifi from the installer
wpa_passphrase "YourSSID" "YourPassword" > /etc/wpa_supplicant.conf
systemctl restart wpa_supplicant
# Or use nmcli/iwctl if available on the ISO

# Clone or copy the repo to the installer environment
# (assuming you have it on USB or can git clone over wifi)
cd /path/to/nixpkgs-repo

# Install NixOS using the flake
nixos-install --flake .#lenovo-p14s

# Set the root password when prompted
# Set jevin's password
nixos-enter --root /mnt -c 'passwd jevin'

# Reboot
reboot
```

## 7. Post-Install

After booting into the new system:

```bash
# Verify the hardware config is correct
rebuildhm  # alias for: cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake '.#lenovo-p14s'

# If rebuildhm is aliased to the framework config, run manually:
cd ~/.config/nixpkgs
sudo nixos-rebuild switch --flake '.#lenovo-p14s'
```

### Set up sops age key

```bash
mkdir -p ~/.config/sops/age
# Copy your age key from another machine or password manager
# The key file goes at: ~/.config/sops/age/keys.txt
```

### Verify hardware is working

```bash
# WiFi (MediaTek MT7925)
lspci | grep -i network    # should show MT7925
ip link                     # should show wlan interface

# GPU (AMD Radeon 860M)
glxinfo | grep "OpenGL renderer"

# Fingerprint reader
fprintd-enroll

# Check kernel version
uname -r                    # should be 6.19.x (linuxPackages_latest)
```

## Adjustments You'll Likely Want

### Update rebuildhm alias

The `rebuildhm` alias points to `'.#framework'`. For the P14s, update your shell config (or add a second alias):

```bash
alias rebuildp14s="cd ~/.config/nixpkgs && sudo nixos-rebuild switch --flake '.#lenovo-p14s'"
```

### Hyprland monitor scripts

The monitor attach/detach scripts in `modules/desktop/hyprland.nix` reference framework-specific resolutions (`2256x1504`, scale `1.5666667`). For the P14s (`2880x1800`, scale `2`), these scripts will need updating if you use external monitors.

### OLED burn-in prevention

The hypridle config already locks after 120s and turns off the display after 180s, which helps. You may also want to consider dimming the display sooner for OLED longevity.

### If kernel 6.19 causes issues

The RDNA 3.5 GPU on Strix Point has had reported instability on some 6.18/6.19 kernels. If you hit GPU hangs or crashes, fall back to the LTS kernel by removing the `boot.kernelPackages` line from `modules/hardware/lenovo-p14s.nix` (the shared boot module defaults to 6.12 LTS).
