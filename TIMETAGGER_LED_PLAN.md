# Winry315 TimeTagger LED Indicator Plan

Goal: when the TimeTagger timer is running (started via macropad F15), the
F15 key LED lights up green. Stopping (F16) turns it off.

## Approach

Custom QMK firmware with Raw HID + host-side LED controller. VIA layout
(F15/F16 keycodes) is preserved in EEPROM and untouched by the flash.

## Stage 1 — Firmware (one-time, manual)

1. **Backup stock firmware.** Build the upstream `via` keymap as the
   known-good recovery image:
   ```
   qmk setup -y                                  # clones ~/qmk_firmware
   qmk compile -kb winry/winry315 -km via
   cp winry_winry315_via.uf2 ~/winry315-stock.uf2
   ```
   Keep this file — drag-and-drop recovery is always possible because the
   RP2040 mask-ROM bootloader cannot be overwritten (BOOT button → RPI-RP2
   USB mass storage → drop .uf2).

2. **Create custom keymap** at
   `~/qmk_firmware/keyboards/winry/winry315/keymaps/jevin/`:
   - Copy `keymaps/via/` as the starting point (keeps VIA enabled).
   - `rules.mk`: add `RAW_ENABLE = yes`.
   - `keymap.c`: add
     ```c
     static bool timer_running = false;

     void raw_hid_receive(uint8_t *data, uint8_t length) {
         if (length >= 2 && data[0] == 0x01) {
             timer_running = (data[1] != 0);
         }
     }

     bool rgb_matrix_indicators_user(void) {
         if (timer_running) {
             rgb_matrix_set_color(LED_F15_INDEX, 0, 255, 0);
         }
         return false;
     }
     ```
   - Look up `LED_F15_INDEX`: F15 is macropad button 8, which in the
     upstream `LAYOUT` macro maps to a specific matrix position. Cross-
     reference `winry315.c` `g_led_config` to find the LED index for that
     key. (To be determined during implementation — open `winry315.c` and
     count matrix → LED mapping.)

3. **Build + flash**:
   ```
   qmk compile -kb winry/winry315 -km jevin
   # Put macropad in bootloader: unplug, hold BOOT, plug in → RPI-RP2 mounts
   cp winry_winry315_jevin.uf2 /run/media/jevin/RPI-RP2/
   ```

4. **Verify**: after reboot, VIA should still connect and show the
   existing F15/F16 keymap. Layer 0 unchanged.

## Stage 2 — Host-side LED control (Nix)

Add to `modules/desktop/hyprland.nix` or a new `modules/desktop/winry315.nix`:

1. **udev rule** for user access to the Winry's hidraw node:
   ```nix
   services.udev.extraRules = ''
     KERNEL=="hidraw*", ATTRS{idVendor}=="6582", ATTRS{idProduct}=="0315", \
       MODE="0660", TAG+="uaccess"
   '';
   ```
   (Confirm VID/PID from `lsusb` after flashing — Winry's vendor/product
   IDs in the upstream `info.json`.)

2. **LED control script** — `winry315-led` shell application:
   - Finds the right `/dev/hidraw*` device by walking
     `/sys/class/hidraw/*/device/uevent` for the matching VID/PID.
   - Writes 2 bytes: `0x01 0x01` (on) or `0x01 0x00` (off).
   - Prepend the HID report ID byte if required by the QMK raw HID
     interface (usually `0x00` prefix).

   Pseudocode:
   ```bash
   winry315-led on|off
   ```

3. **Integrate with `timetagger-ctl`**: after a successful start, call
   `winry315-led on`; after a successful stop, call `winry315-led off`.

4. **Crash safety**: on Hyprland session start, call `winry315-led off`
   so a stale indicator from a previous session doesn't mislead.

## Stage 3 — Optional polish

- Blink the LED once on API failure (different color = error state).
- Second indicator LED: F16 stays dim red when no timer is running,
  so you can tell "off" from "unpowered".
- Sync on boot: have the activation script query the TimeTagger API for
  a running record and set the LED accordingly (handles reboots mid-timer).

## Open questions / to resolve during implementation

1. Exact LED index for the F15 key in `g_led_config`.
2. Winry315 USB VID/PID (from `info.json` in upstream QMK).
3. Whether QMK raw HID needs a leading report ID byte on Linux hidraw
   (it does on some firmwares, not others — test empirically).
4. Whether to ship the custom firmware build via a Nix derivation
   (`pkgs/winry315-firmware.nix` calling `qmk compile` in a sandboxed
   build) for reproducibility, or keep it out-of-band since flashing is
   manual anyway. Probably the latter for simplicity.

## Risk assessment

- **Bricking: effectively zero.** RP2040 mask-ROM bootloader is
  unoverwritable. Worst case = drag stock .uf2 back on.
- **VIA layout loss: zero.** VIA config lives in EEPROM, which the
  flash doesn't touch (unless the firmware version bumps the EEPROM
  magic, which a same-version recompile won't).
- **Time cost: ~1-2 hours** end-to-end once QMK is cloned, mostly
  spent verifying LED index and the hidraw handshake.
