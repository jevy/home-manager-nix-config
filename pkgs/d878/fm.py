#!/usr/bin/env python3
"""AnyTone AT-D878UV FM broadcast (WFM) settings, which dmrconf can't write.

qdmr knows the memory layout (lib/d878uv_codeplug.hh, lib/anytone_codeplug.cc)
but never encodes these fields, so the radio sits in FM "MEM" mode with an
empty station list and the knob does nothing. This talks the same serial
protocol as qdmr's anytone_interface.cc and touches ONLY these blocks:

  0x02500000 +0x1d  FM work channel index (memory loaded on entering FM)
             +0x1e  FM VFO enabled (0 = MEM, 1 = VFO)
             +0x2b  FM monitor (keep receiving ham channel while FM plays)
  0x02480000        100 stations x 4 bytes, BCD big-endian, 100 Hz units
                    (qdmr code reads _le; the radio is _be: 99.1 = 00 99 10 00)
  0x02480200        FM VFO frequency (same encoding)
  0x02480210        32-byte bitmap of valid stations, LSB first

Protocol: "PROGRAM" -> "QX\\x06"; 0x02 -> 16-byte 'I' identity; reads are
'R' addr(be32) 0x10 -> 'W' addr 0x10 data[16] sum 0x06; writes are
'W' addr 0x10 data[16] sum 0x06 -> 0x06; sum = bytes[1..21] mod 256; "END".

  fm.py show
  fm.py write STATIONS_FILE BACKUP_DIR
  fm.py restore BACKUP_JSON
"""
import glob
import json
import sys
import time
from datetime import datetime
from pathlib import Path

import serial

SETTINGS = 0x02500000
WFM_CHANNELS = 0x02480000
WFM_VFO = 0x02480200
WFM_BITMAP = 0x02480210
SETTINGS_SIZE = 0xF0     # whole D878UV GeneralSettingsElement
OFF_WORK, OFF_VFO, OFF_MON = 0x1D, 0x1E, 0x2B
N_STATIONS = 100


def port():
    ids = glob.glob("/dev/serial/by-id/*GD32*") + glob.glob("/dev/serial/by-id/*28e9*")
    return ids[0] if ids else "/dev/ttyACM0"


class Radio:
    def __init__(self):
        self.s = serial.Serial(port(), 115200, timeout=2)
        self.s.reset_input_buffer()
        self._xfer(b"PROGRAM", 3, expect=b"QX\x06")
        ident = self._xfer(b"\x02", 16)
        model = ident[1:8].split(b"\0")[0].decode(errors="replace").strip()
        version = ident[9:15].split(b"\0")[0].decode(errors="replace").strip()
        if ident[0:1] != b"I" or ident[15] != 6 or "878" not in model:
            self.close()
            sys.exit(f"unexpected radio identity {ident!r}; refusing to continue")
        print(f"radio: {model} {version}")

    def _xfer(self, cmd, n, expect=None):
        self.s.write(cmd)
        resp = self.s.read(n)
        if len(resp) != n or (expect is not None and resp != expect):
            raise IOError(f"bad response to {cmd[:8]!r}: {resp!r}")
        return resp

    def read(self, addr, size):
        out = b""
        for a in range(addr, addr + size, 16):
            r = self._xfer(b"R" + a.to_bytes(4, "big") + b"\x10", 24)
            if (r[0:1] != b"W" or int.from_bytes(r[1:5], "big") != a or r[5] != 16
                    or sum(r[1:22]) & 0xFF != r[22] or r[23] != 6):
                raise IOError(f"bad read response at {a:#010x}: {r.hex()}")
            out += r[6:22]
        return out

    def write(self, addr, data):
        assert len(data) % 16 == 0
        for i in range(0, len(data), 16):
            body = (addr + i).to_bytes(4, "big") + b"\x10" + data[i:i + 16]
            self._xfer(b"W" + body + bytes([sum(body) & 0xFF, 6]), 1, expect=b"\x06")

    def close(self):
        if not self.s.is_open:
            return
        try:
            self.s.write(b"END")
            self.s.read(1)
        finally:
            self.s.close()


def bcd_to_mhz(b):
    v = int.from_bytes(b, "big")
    if v in (0, 0xFFFFFFFF):
        return None
    digits = f"{v:08x}"
    if not digits.isdigit():
        return None
    return int(digits) * 100 / 1e6


def mhz_to_bcd(mhz):
    return int(f"{round(mhz * 1e4):08d}", 16).to_bytes(4, "big")


def read_all(r):
    return {
        "settings": r.read(SETTINGS, SETTINGS_SIZE),
        "channels": r.read(WFM_CHANNELS, 0x200),
        "vfo": r.read(WFM_VFO, 0x10),
        "bitmap": r.read(WFM_BITMAP, 0x20),
    }


def stations(blocks):
    bm, ch = blocks["bitmap"], blocks["channels"]
    return [(i, bcd_to_mhz(ch[4 * i:4 * i + 4])) for i in range(N_STATIONS)
            if bm[i // 8] & (1 << (i % 8))]


def show(blocks):
    s = blocks["settings"]
    print(f"mode:         {'VFO' if s[OFF_VFO] else 'MEM'}   (raw {s[OFF_VFO]})")
    print(f"work channel: {s[OFF_WORK] + 1}   (raw {s[OFF_WORK]})")
    print(f"monitor:      {'on' if s[OFF_MON] else 'off'}   (raw {s[OFF_MON]})")
    print(f"vfo freq:     {bcd_to_mhz(blocks['vfo'][0:4])} MHz")
    st = stations(blocks)
    print(f"stations:     {len(st)}")
    for i, f in st:
        print(f"  {i + 1:3}  {f} MHz")


ADDRS = {"settings": SETTINGS, "channels": WFM_CHANNELS,
         "vfo": WFM_VFO, "bitmap": WFM_BITMAP}


def write_changed(r, addrs, before, want):
    """Rewrite each changed element WHOLE, contiguously from its base.

    Never write partial chunks: a 16-byte write into the middle of an
    element makes the radio erase the surrounding flash page, and every
    byte not rewritten in that session comes back 0xFF. That wiped the
    general settings once (2026-11-07: Chinese UI, repaired from the .dfu
    backup). qdmr always writes whole elements, which is safe.
    """
    if before["channels"] != want["channels"] or before["vfo"] != want["vfo"] \
            or before["bitmap"] != want["bitmap"]:
        block = want["channels"] + want["vfo"] + want["bitmap"]   # 0x02480000..0x0248022f
        r.write(WFM_CHANNELS, block)
        print(f"wrote FM block ({len(block)} bytes at {WFM_CHANNELS:#010x})")
    if before["settings"] != want["settings"]:
        assert len(want["settings"]) == SETTINGS_SIZE
        r.write(SETTINGS, want["settings"])
        print(f"wrote settings element ({SETTINGS_SIZE} bytes at {SETTINGS:#010x})")


def parse_stations(path):
    out = []
    for line in Path(path).read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        mhz = float(line.split()[0])
        if not 76.0 <= mhz <= 108.0:
            sys.exit(f"{mhz} MHz is outside 76-108 MHz")
        out.append(mhz)
    if not 0 < len(out) <= N_STATIONS:
        sys.exit(f"need 1..{N_STATIONS} stations, got {len(out)}")
    return out


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "write":
        freqs = parse_stations(sys.argv[2])
        backup_dir = Path(sys.argv[3])
    elif cmd == "restore":
        saved = {k: bytes.fromhex(v) for k, v in json.loads(Path(sys.argv[2]).read_text()).items()}
    elif cmd != "show":
        sys.exit(__doc__)

    r = Radio()
    try:
        before = read_all(r)
        if cmd == "show":
            show(before)
            return
        if cmd == "restore":
            write_changed(r, ADDRS, before, saved)
            r.close()
            verify(saved, "restore did not take")
            return

        backup = backup_dir / f"fm-backup-{datetime.now():%F-%H%M%S}.json"
        backup.write_text(json.dumps({k: v.hex() for k, v in before.items()}, indent=1))
        print(f"backup: {backup}")

        settings = bytearray(before["settings"])
        settings[OFF_VFO] = 1
        settings[OFF_WORK] = 0
        settings[OFF_MON] = 1
        channels = b"".join(mhz_to_bcd(f) for f in freqs).ljust(0x200, b"\0")
        vfo = mhz_to_bcd(freqs[0]) + before["vfo"][4:]
        bitmap = bytearray(0x20)
        for i in range(len(freqs)):
            bitmap[i // 8] |= 1 << (i % 8)

        want = {"settings": bytes(settings), "channels": channels,
                "vfo": vfo, "bitmap": bytes(bitmap)}
        addrs = ADDRS
        write_changed(r, addrs, before, want)
    finally:
        r.close()
    # Never read in the same session after writing: the radio drops the
    # pending writes (observed). Verify after END + reboot instead.
    verify(want, f"restore with: d878 fm restore {backup}")


def wait_reboot():
    time.sleep(12)
    for _ in range(30):
        if glob.glob("/dev/ttyACM*"):
            time.sleep(4)
            return
        time.sleep(2)
    sys.exit("radio did not come back on USB")


def verify(want, hint):
    print("waiting for reboot to verify...")
    wait_reboot()
    r = Radio()
    try:
        after = read_all(r)
    finally:
        r.close()
    bad = [k for k in want if after[k] != want[k]]
    if bad:
        sys.exit(f"VERIFY FAILED for {bad}; {hint}")
    print("verified after reboot:")
    show(after)


if __name__ == "__main__":
    main()
