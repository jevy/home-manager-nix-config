# Ikoka Stick (MeshCore repeater node)

DIY Meshtastic/MeshCore carrier board: https://github.com/ndoo/ikoka-stick-meshtastic-device

## Hardware

- **Carrier board:** Ikoka Stick (EBYTE E22 LoRa module + 21700 battery holder / LiPo PicoBlade connector)
- **MCU:** Seeed Studio XIAO nRF52840 **Sense** (socketed, serial `CC1630A6B30CFD91`)
- **Charging:** handled by the XIAO's onboard charger; battery is wired to the BAT+/BAT- pads on the back of the XIAO. Solar = plug a 5V USB-C panel into the XIAO's USB-C port.
- ⚠️ **Never connect a 21700 and a LiPo pouch at the same time** — they short together in parallel.
- ⚠️ **If the LoRa module is an E22-*33S (2W):** never transmit without an antenna, and keep TX power **≤ 9 dBm** (the RF frontend fries above that on this board).
- Intended deployment: solar-powered repeater in a tree (Ottawa). Print the enclosure in PETG/ASA, not PLA.

## Firmware choice

**MeshCore** (meshcore.io), *not* Meshtastic — they are incompatible networks. Flasher
target: **Seeed Studio Xiao nRF52 WIO** (release asset name `Xiao_nrf52_*`),
role: **Repeater**.

## What was done (2026-07-25)

1. **Diagnosed why the web flasher failed:** the XIAO shipped with a defective/nonstandard
   bootloader — it never exposed the `XIAO-BOOT` UF2 drive (CDC-only USB descriptors in
   every mode) and its serial DFU only responded intermittently. Double-click reset
   appeared to do nothing because there was no drive/LED behavior to see.
2. Flashed Meshtastic 2.7.26 via CLI serial DFU (worked, verified with `meshtastic --info`)
   before realizing the goal was MeshCore.
3. **Installed the OTAFIX bootloader** `0.9.2-OTAFIX2.2-BP1.3` + SoftDevice S140 7.3.0
   (https://github.com/oltaco/Adafruit_nRF52_Bootloader_OTAFIX — the one MeshCore's FAQ
   recommends for repeaters; falls back to DFU instead of bricking on a bad OTA update).
   Asset used: `xiao_nrf52840_ble_sense_bootloader-0.9.2-OTAFIX2.2-BP1.3_s140_7.3.0.zip`.
   After this flash the board correctly exposed the `XIAO-BOOT` mass-storage drive for the
   first time — confirming the old bootloader was the root problem.
4. **Gotcha discovered:** after the bootloader install the board appeared dead on USB
   (`device descriptor read, error -110`). Not a hardware fault — **OTAFIX ≥2.0 defaults to
   OTA (BLE) DFU mode when no valid app is present** and deliberately exposes no USB drive or
   serial port. Fix: **double-click RST** to explicitly enter UF2/serial mode.
5. **Flashed MeshCore repeater firmware v1.16.0** (`Xiao_nrf52_repeater-v1.16.0-07a3ca9.zip`,
   from https://github.com/meshcore-dev/MeshCore/releases/tag/repeater-v1.16.0) via serial
   DFU. Verified over the serial console (`ver` → `v1.16.0-07a3ca9`).
6. **Configured the radio** over the USB serial console (115200 baud):
   - `set tx 9` — TX power 9 dBm (safe ceiling in case the E22 is a 33S/2W module;
     shipped default was 22 dBm on the EU frequency!)
   - `set radio 910.525,62.5,7,5` — the "USA/Canada (Recommended)" preset:
     910.525 MHz / 62.5 kHz BW / SF7 / CR5
   - `repeat` is `on` (default), flood advert interval 47 min.
   - `set name VA3JEV_Repeater`
   - Admin password changed from the factory default (stored in the usual password
     manager — note: **MeshCore truncates passwords to 15 chars**).
   - `set lat 45.4450` / `set lon -75.6117` — repeater location (Ottawa).
   - **Still TODO:** confirm the E22 module variant before raising TX power above 9 dBm.
7. **Custom-built firmware for the OLED** (stock release zips have no display support —
   reflashing a stock zip turns the screen off again). Built from MeshCore source at tag
   `repeater-v1.16.0`; the full diff is saved as **`docs/ikoka-stick-oled.patch`** in this
   repo. Summary of the changes (all in `variants/xiao_nrf52/`):
   - `platformio.ini`: swap I2C pins to match Ikoka wiring (`PIN_WIRE_SDA=D6`,
     `PIN_WIRE_SCL=D7` — MeshCore ships them reversed), add `-D PIN_OLED_RESET=-1`,
     set `DISPLAY_CLASS=SSD1306Display`, swap `NullDisplayDriver.cpp` →
     `SSD1306Display.cpp` in `build_src_filter`, add lib dep
     `adafruit/Adafruit SSD1306 @ ^2.5.13`, and remap `PIN_USER_BTN=D0` (the Ikoka's
     user button pin — MeshCore's default `PIN_BUTTON1` doesn't exist on this board).
     The OLED auto-blanks after 20 s (`AUTO_OFF_MILLIS` in the repeater's UITask.cpp);
     pressing the user button wakes it for another 20 s.
   - `target.h`: `#include <helpers/ui/NullDisplayDriver.h>` →
     `<helpers/ui/SSD1306Display.h>` (upstream bug for any Xiao display build;
     would make a reasonable PR to meshcore-dev/MeshCore)
   - To rebuild from scratch:
     ```bash
     git clone --depth 1 --branch repeater-v1.16.0 https://github.com/meshcore-dev/MeshCore.git
     cd MeshCore && git apply /path/to/docs/ikoka-stick-oled.patch
     nix-shell -p platformio --run "pio run -e Xiao_nrf52_repeater"
     # flash .pio/build/Xiao_nrf52_repeater/firmware.zip via serial DFU (see below)
     ```
   Settings (name/radio/password) persist across app reflashes. This firmware is what is
   currently on the device.
8. **OLED shows nothing — was a hardware contact problem, now FIXED.** A temporary
   diagnostic build that bit-banged an I2C scan on D6/D7 (both SDA/SCL orders, full
   0x08–0x77 address range) initially found **no device ACKing at all** — the display was
   electrically absent. After physically reseating the display, a second diagnostic
   (line-state check: SSD1306 modules have onboard pull-ups, so a powered+connected module
   pulls SDA/SCL HIGH) showed both lines HIGH and an **ACK at 0x3C** on SDA=D6/SCL=D7 —
   exactly what the firmware expects. Reflashed the clean OLED firmware; display works.
   **Lesson:** the display header is press-fit sensitive — if the screen ever goes dark
   again, reseat (or solder) the header first. If a replacement module ACKs at 0x3D
   instead, rebuild with `-D DISPLAY_ADDRESS=0x3D`.

## How to flash firmware (no browser needed)

With the OTAFIX bootloader, two options once the board enumerates:

**Option A — UF2 drag & drop (easiest):**
Double-click the tiny RST button next to the USB-C port (or it lands in DFU automatically
when there's no valid app). A `XIAO-BOOT` drive appears; copy the `.uf2` file onto it.
It flashes itself and reboots.

**Option B — serial DFU from the CLI:**

```bash
# If an app is running, kick it into the bootloader first (1200-baud touch):
stty -F /dev/ttyACM0 1200 && sleep 3
# Device should re-enumerate as bootloader (lsusb: 2886:0045 or 239a:810b)

# Flash a Nordic DFU .zip package:
NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_INSECURE=1 \
  nix shell --impure nixpkgs#adafruit-nrfutil -c \
  adafruit-nrfutil dfu serial --package <firmware>.zip -p /dev/ttyACM0 -b 115200 --singlebank
```

Notes:
- `adafruit-nrfutil` is unfree + depends on an insecure `ecdsa`, hence the env vars.
- Meshtastic's `-ota.zip` release assets are valid serial-DFU packages; MeshCore's `.zip`
  assets likewise.
- If serial DFU says "No data received", the port is in the wrong mode — do the 1200-baud
  touch again (it toggles between two bootloader USB modes).
- If Meshtastic is running, `meshtastic --port /dev/ttyACM0 --enter-dfu` is the reliable
  way into the bootloader (the 1200-baud touch doesn't always reset the Meshtastic app).

## Managing the node once MeshCore is on it

- **Configure:** MeshCore web console at https://meshcore.io/flasher → Config/Console (USB
  serial), or the MeshCore phone app over BLE. Set: region/frequency preset for Canada
  (915 MHz), node name, repeater settings, **TX power ≤ 9 dBm if the E22 is a 33S module**.
- **Repeater firmware has no companion/phone chat role** — it just routes. Admin access is
  over BLE or USB console with the admin password (set one!).
- **OTA updates:** possible over BLE thanks to the OTAFIX bootloader; if an update fails,
  the board falls back into DFU mode instead of bricking — recover with either flash method
  above.
- **Firmware updates:** grab the newest `Xiao_nrf52_repeater-*.zip`/`.uf2` from
  https://github.com/meshcore-dev/MeshCore/releases (tags named `repeater-vX.Y.Z`).

## Where things sit

- This doc: `docs/ikoka-stick.md` (this repo)
- OLED firmware patch: `docs/ikoka-stick-oled.patch` (this repo) — apply to a MeshCore
  checkout at tag `repeater-v1.16.0` and build; see step 7 above.
- Firmware/bootloader files and the MeshCore source checkout from the session lived in the
  Claude scratchpad (ephemeral); re-download/rebuild from the GitHub URLs above when needed.
- Useful references:
  - Ikoka Stick docs (pinout, battery wiring, 33S warnings): https://github.com/ndoo/ikoka-stick-meshtastic-device
  - OTAFIX bootloader: https://github.com/oltaco/Adafruit_nRF52_Bootloader_OTAFIX
  - MeshCore FAQ: https://github.com/meshcore-dev/MeshCore/blob/main/docs/faq.md
