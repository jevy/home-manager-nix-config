To run the config:
`sudo nixos-rebuild switch --flake .#`

This flake will look at the hostname to determine which derivation to build.

## Kernel crash capture (pstore)

When the machine hard-locks, the kernel usually can't flush its logs to disk, so
`journalctl` shows the boot cut off mid-line with no backtrace. The panic *is*
captured though — via **pstore**, which NixOS wires up out of the box:

- The kernel writes the oops/panic ring buffer to the **efi-pstore** backend
  (`CONFIG_EFI_VARS_PSTORE=y`, stored in EFI NVRAM) as it dies.
- On the next boot, **`systemd-pstore.service`** (enabled by default on NixOS)
  evacuates those records to disk and clears NVRAM.

There is nothing to enable — it works on a stock NixOS install. On `lenovo-p14s`
we additionally set `printk.always_kmsg_dump=1` so the *full* ring buffer is
dumped, not just the tail (see `modules/hardware/lenovo-p14s.nix`).

### Reading a captured crash

Archived dumps live under `/var/lib/systemd/pstore/`, one directory per crash
(named by unix timestamp). The reconstructed backtrace is `dmesg.txt` (root-only):

```bash
# newest crashes first
sudo ls -lt /var/lib/systemd/pstore/

# read the full backtrace of a given crash
sudo cat /var/lib/systemd/pstore/<timestamp>/*/dmesg.txt

# just the interesting lines
sudo grep -iE 'kernel BUG|RIP:|Call Trace|Comm:|Hardware name|list_add' \
  /var/lib/systemd/pstore/<timestamp>/*/dmesg.txt
```

### Known recurring panic on lenovo-p14s (MT7925 Wi-Fi)

Kernel 7.1's `mt7925` MLO/station-teardown rework races the NAPI RX poll and
hard-locks the laptop under network load:

```
kernel BUG at lib/list_debug.c:32   (list_add corruption)
  mt7925_mac_add_txs.part.0  [mt7925_common]   (also: mt7925_mac_tx_free)
  mt792x_poll_rx             [mt792x_lib]       (Comm: napi/phy0-0)
```

The fix (upstream `20b126920a25`) is only in unreleased mainline v7.2-rc1, so no
released stable kernel carries it. Until then `lenovo-p14s` **pins the kernel to
7.0.6** (which predates the 7.1 rework). Root-cause notes, the upstream fix link,
and the mitigation/auto-recovery config (`panic=10`, hardware watchdog) are
documented inline in `modules/hardware/lenovo-p14s.nix`.

> **Caveat:** efi-pstore writes to EFI NVRAM. If `systemd-pstore` ever stops
> clearing it (check `ls /sys/firmware/efi/efivars/ | grep -c cfc8fc79`), records
> can accumulate; the fix is switching pstore to a `ramoops` RAM backend.
