# MeshCore: LoRa mesh messaging against a companion radio.
#
# Two clients, both talking to the same radio over BLE, USB serial or TCP:
#
#   meshy         GTK4/libadwaita GUI -- chat, channels, contacts + QR,
#                 libshumate map with RSSI/SNR overlays, repeater admin,
#                 radio config and backup/restore. Not in nixpkgs, so it is
#                 built from ../../pkgs/meshy.nix (Codeberg tag 26.09).
#   meshcore-cli  Official CLI, straight from nixpkgs. Scriptable, and the
#                 only one of the two that runs over SSH on a headless box.
#
# Which transport you get is decided at FLASH time, not at connect time. The
# firmware's MultiSerialInterface (src/helpers/MultiSerialInterface.h) does fan
# out to every registered interface, but each board's platformio env registers
# only the ones it compiles in, and for the T-LoRa those are separate envs:
#
#   LilyGo_TLora_V2_1_1_6_companion_radio_ble   -D BLE_PIN_CODE=123456  (no USB)
#   LilyGo_TLora_V2_1_1_6_companion_radio_usb   -D ENABLE_USB_INTERFACE (no BLE)
#   LilyGo_TLora_V2_1_1_6_companion_radio_wifi  TCP only
#
# So on our T-LoRa V2.1-1.6 you pick one. Only 11 envs in the whole firmware
# tree define BLE_PIN_CODE and ENABLE_USB_INTERFACE together, and they are all
# nRF52/RP2040 boards (Heltec T114, RAK11310, PicoW, Xiao RP2040 and friends).
# A silent /dev/ttyACM0 on a _ble build is therefore correct behaviour, not a
# fault -- the port enumerates for flashing but nothing speaks the companion
# protocol on it.
#
# BLE is single-client regardless. esp32/SerialBLEInterface.cpp keeps one
# deviceConnected flag and one conn_id, stops advertising on connect, and only
# restarts it once getConnectedCount() == 0. A second BLE client is not
# refused, it just stops seeing the radio in its scan -- which reads as dead
# hardware rather than a busy peer. Several devices can stay *bonded* (the
# firmware never deletes bonds), they simply take turns.
#
# The BLE pin is persisted in prefs (_prefs.ble_pin, DataStore.cpp) and
# begin() is handed getBLEPin(), so 123456 is only the factory default -- a pin
# changed from a client sticks across reflashes of the app partition.
#
# Our T-LoRa runs the _wifi build and listens on TCP 5000. It is joined to the
# IoT SSID rather than the main one, picked on three criteria worth re-checking
# if it ever moves: the SSID must carry 2.4GHz BSSes (the ESP32-PICO-D4 has no
# 5GHz radio), WPA2-only avoids WPA2/WPA3 transition-mode PMF trouble on the
# ESP32, and whatever VLAN it lands on has to be reachable on arbitrary TCP
# ports from wherever the clients live. Connect with `meshcore-cli -t <ip>` or
# Meshy's TCP transport. Addresses and SSIDs are deliberately not recorded here
# -- this repo is public.
#
# TCP is single-client too, and worse than BLE about it: SerialWifiInterface
# holds one WiFiClient and a new connection calls client.stop() on the old one,
# so two clients pointed at the radio evict each other in a loop with no error
# on either side. Concurrent clients need a mux in front (we run
# compumike/meshcore-tcp-mux, which holds the single upstream session and fans
# it out). Point clients at the mux, never at the radio as well.
#
# WiFi credentials are compile-time only (no runtime setter, nothing in
# NodePrefs), so rebuilding is the only way to change networks. Edit the two
# -D WIFI_SSID / -D WIFI_PWD lines in variants/lilygo_tlora_v2_1/platformio.ini
# to read ${sysenv.MC_WIFI_SSID} / ${sysenv.MC_WIFI_PWD}, then:
#
#   MC_WIFI_SSID=<ssid> MC_WIFI_PWD="$(op read 'op://<vault>/<item>/<field>')" \
#     nix run nixpkgs#platformio -- run -e LilyGo_TLora_V2_1_1_6_companion_radio_wifi
#
# The PSK is in 1Password under the IoT network's item. Note it is stored in an
# AirPort-template field, so check which field is actually populated rather than
# assuming the obvious one. The credentials are baked into the flashed image.
#
# Reflashing app0 only (esptool write-flash 0x10000 firmware.bin) leaves the
# node intact: partitions are app0 0x010000+0x1e0000, app1 0x1f0000+0x1e0000,
# spiffs 0x3d0000+0x030000, so a ~1.5MB image cannot reach SPIFFS. Identity,
# radio prefs and all 159 contacts survived the 1.16.0-BLE -> 1.17.1-WiFi
# switch. Do NOT flash the -merged.bin at 0x0; that one carries the partition
# table and would take the filesystem with it.
#
# Gotcha when verifying: `meshcore-cli contacts` reports "0 contacts in device"
# for the first ~30s after boot, before the list is loaded. It is not data
# loss. Wait for the node to settle and ask again before concluding anything.
#
# TRAP, cost an afternoon 2026-09-24: do NOT try to override the stock flags
# with -UWIFI_SSID -DWIFI_SSID=... from a derived env or PLATFORMIO_BUILD_FLAGS.
# PlatformIO parses -D into SCons CPPDEFINES but -U into CCFLAGS, and SCons
# emits CCFLAGS *after* CPPDEFINES, so the undef always wins no matter how you
# order them. WIFI_SSID then ends up undefined, main.cpp's `#ifdef WIFI_SSID`
# compiles the whole WiFi block out, and you get a clean [SUCCESS] build of a
# radio with no networking. The tell is the size: a correct wifi build is
# 1498077 bytes / 76.2% flash / 33.9% RAM, the broken one 1007681 / 51.3% /
# 26.8%. Always check the size, and grep the .bin for the SSID before flashing.
#
# Serial permissions need nothing extra here: NixOS gives ttyACM*/ttyUSB* to
# root:dialout, and modules/base/user.nix already has jevin in dialout.
# Upstream ships data/linux/60-meshy-serial.rules (a blanket TAG+="uaccess" on
# every ttyACM*/ttyUSB*) for distros that do not; installing it would widen
# access to every serial device on the machine for no gain here. BLE needs
# nothing either -- meshy talks to BlueZ over GDBus, and bluetooth is already
# on via modules/desktop/audio.nix.
{ ... }:
{
  flake.modules.homeManager.meshcore =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.callPackage ../../pkgs/meshy.nix { })
        pkgs.meshcore-cli
      ];
    };
}
