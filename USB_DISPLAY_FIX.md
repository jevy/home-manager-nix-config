# USB Display Fix — ThinkPad P14s Gen 6 AMD

## Problem

USB-C external display not working. Previous diagnosis: **power delivery issue**.
Other users reported that "reflashing the EC" fixed it — on Gen 6 that's actually
a PD controller firmware reflash triggered by the BIOS update chain.

## Current State (verified 2026-04-11)

- **Host**: Lenovo ThinkPad P14s Gen 6 AMD (21QLCTO1WW)
- **BIOS**: R2XET37W (1.17), EC 1.9, System Firmware 0.1.17 — all latest per fwupd
- **Kernel**: 6.19.10 (`amdgpu.dcdebugmask=0x10 amdgpu.cwsr_enable=0 amd_pstate=active acpi.ec_no_wakeup=1`)
- **USB-C PD**: both ports advertise DP alt mode (VESA SVID `ff01`) — hardware path is wired
- **`typec_displayport` module**: NOT auto-loaded (`CONFIG_TYPEC_DP_ALTMODE=m` is set, loads fine manually)

## Root Cause (likely)

Known class of bugs on **AMD Ryzen AI 300** platforms — USB-C display + PD firmware
interaction. Confirmed fixed by PD firmware updates on:
- Framework 13 AI 300 (same CPU silicon)
- ThinkPad E14/E16 Gen 6 AMD
- Community reports on P14s Gen 6 AMD

On Gen 6 there is **no standalone EC flash**. The "EC reflash fixed it" stories mean
the user walked **BIOS 1.13 → 1.14 → 1.15** sequentially, which re-flashes the PD
controller MCU firmware as a side effect. fwupd/LVFS jumps straight to the latest
capsule and may **not** trigger the sequential PD update, leaving the PD firmware at
factory version even though the BIOS version bumps.

## Fixes (cheapest first)

### 1. Pinhole emergency reset (free, 90 seconds)
1. Unplug AC, remove all USB devices/docks
2. Flip laptop, find pinhole on bottom
3. Hold paperclip in for 60 seconds
4. Reconnect AC, power on, retest

Resolved the P1 Gen 6 USB-C/TB4 case in forum threads.

### 2. Force-load `typec_displayport` at boot

Add to NixOS config:
```nix
boot.kernelModules = [ "typec_displayport" ];
```

Kernel has the module but doesn't auto-load it. Some distros load on demand when
hardware is detected; Arch BBS reports show it sometimes needs forcing.

### 3. Temporarily remove `acpi.ec_no_wakeup=1`

Comes from nixos-hardware's `lenovo/thinkpad/p14s/amd/gen6/default.nix`. Could
theoretically suppress EC-driven USB-C hotplug notifications. Test boot without it.

### 4. Force PD firmware reflash via Lenovo bootable ISO

The real "EC reflash". fwupd alone will not walk the chain.

```bash
# Download DS574808 bootable CD ISO from
# https://support.lenovo.com/us/en/downloads/DS574808

nix-shell -p perl genisoimage
wget https://userpages.uni-koblenz.de/~krienke/ftp/noarch/geteltorito/geteltorito
chmod +x geteltorito
./geteltorito -o bios.img r2xuj17w.iso  # filename may vary
sudo dd if=bios.img of=/dev/sdX bs=4M status=progress  # X = USB stick

# Boot from USB (F12 boot menu)
# Pick "Update system firmware"
# Walks 1.13 → 1.14 → 1.15 → 1.17 in order, reflashing PD controller
# After flashing: F1 → Load BIOS Defaults (fixes 1.17 s2idle regression)
```

### 5. BIOS settings to verify (F1 at boot)

- **USB-C DP Alt Mode**: enabled
- **Thunderbolt BIOS Assist Mode**: disabled
- **Always On USB**: disabled (known PD interaction with some docks)

## Known Gotchas

- **BIOS 1.17 s2idle regression** on Fedora 43 / T14 Gen 6 AMD — fixed by
  "Load BIOS Defaults" after flashing
- **fwupd issues #542, #547** (firmware-lenovo) — some P14s Gen 6 machines report
  System Firmware version as `0` instead of real version. Yours reports correctly.
- **PD firmware version not exposed to OS** — no way to read from Linux, only way
  to verify is to walk the sequential update chain
- **Kernel 6.19.10 is very new** — ArchWiki notes stability issues with newer
  kernels on Ryzen AI 300. Worth trying 6.17 LTS to rule out a regression.

## References

- [Lenovo firmware bundle DS574808](https://support.lenovo.com/us/en/downloads/DS574808)
- [ArchWiki P14s Gen 6 AMD](https://wiki.archlinux.org/title/Lenovo_ThinkPad_P14s_(AMD)_Gen_6)
- [Framework AI 300 USB-C monitor fix](https://community.frame.work/t/solved-issues-connecting-to-usb-c-monitor-amd-ryzen-ai-350/68468)
- [Fedora BIOS 1.17 s2idle regression](https://discussion.fedoraproject.org/t/suspend-broken-s2idle-on-thinkpad-t14-gen-6-amd-after-bios-1-17-fedora-43/178657)
- [E14/E16 Gen 6 AMD USB-C megathread](https://www.reddit.com/r/Lenovo/comments/1hhd5ib/psa_lenovo_usbc_port_failures_a_serious_ongoing/)
- [P1 Gen 6 pinhole reset fix](https://www.reddit.com/r/thinkpad/comments/1auv9q0/p1_gen6_usbctb4_ports_stopped_working_with/)
- [fwupd firmware-lenovo #542](https://github.com/fwupd/firmware-lenovo/issues/542)
- [fwupd firmware-lenovo #547](https://github.com/fwupd/firmware-lenovo/issues/547)
- [Linux BIOS flash via geteltorito](https://www.cyberciti.biz/faq/update-lenovo-bios-from-linux-usb-stick-pen/)
