# Lenovo ThinkPad P14s Gen 6 AMD hardware configuration
{ inputs, ... }:
{
  flake.modules.nixos.lenovoP14sHardware =
    { pkgs, ... }:
    {
      # Kernel PINNED to 7.0.6 (via the nixpkgs-kernel706 flake input) to stop
      # MT7925 hard-locks under network load. NOT linuxPackages_latest — see below.
      #
      # ROOT CAUSE (confirmed against captured pstore dumps + upstream git, 2026-07):
      # kernel 7.1's mt7925 MLO / station-teardown rework (RCU wcid lifetime, the
      # 2026-03-06 series) races the NAPI RX poll. mt76_wcid_init re-initializes a
      # wcid->poll_list that the RX path (mt7925_mac_add_txs → mt76_wcid_add_poll)
      # may already have linked → "kernel BUG at lib/list_debug.c:32" (list_add
      # corruption), Comm napi/phy0-0. Verified: the crash-site functions
      # (mt7925_mac_add_txs, mt7925_mac_tx_free, mt7925_rx_check, mt76_tx_status_*)
      # are byte-identical 7.0.6↔7.1.1 — the regression is the *teardown* churn that
      # is NEW in 7.1, so 7.0.6 (which predates it) does not hit this. Empirically:
      # 7.0.6 ran clean ~26 days on this machine (gens through Jun 26); 7.1.1 landed
      # Jun 26 and produced 4 list_add BUG panics in 3 days (one 7 min after boot).
      #
      # The fix is upstream commit 20b126920a25 ("wifi: mt76: add wcid publish check
      # in mt76_sta_add") but it is ONLY in mainline v7.2-rc1 — unreleased, no
      # Cc: stable, so no 7.1.x/7.0.x release carries it. Downgrading is therefore
      # the only *released* crash-free path; going forward within 7.1 does not help.
      # TODO: drop this pin + restore pkgs.linuxPackages_latest once a release ships
      # 20b126920a25 (v7.2, est. late Aug 2026); alternatively cherry-pick it via
      # boot.kernelPatches to stay current. Track the upstream/stable-backport status.
      #
      # Bonus: 7.0.6 also predates the 7.0.7 MT7925 Bluetooth break (btmtk rejecting
      # the short WMT FUNC_CTRL event, "-22"; broken by 634a4408c061, fixed by
      # e193447ac6c9 in 7.1) — so BT works here too. The xdg-desktop-portal
      # /proc/<pid>/root breakage is version-independent (CVE-2026-46333 get_dumpable
      # tightening, 31e62c2ebbfd, in both 7.0.6 and 7.1.x); it's handled by the
      # security.wrappers CAP_SYS_PTRACE shim below regardless of kernel version.
      boot.kernelPackages =
        inputs.nixpkgs-kernel706.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_latest;

      # The pinned kernel comes from an older nixpkgs (May) than the rest of this
      # config (current unstable), whose NixOS modules read kernel passthru attrs
      # the older derivation doesn't expose → eval errors. Supply the values
      # explicitly so the throwing defaults are never forced. Both are x86_64
      # constants; remove together with the kernel pin.
      #   - hardware.deviceTree.enable default reads kernel.buildDTBs (x86 has none)
      #   - system.boot.loader.kernelFile default reads kernel.target (= bzImage)
      hardware.deviceTree.enable = false;
      system.boot.loader.kernelFile = "bzImage";

      # Fix OLED/PSR screen flickering on RDNA 3.5 (Strix Point)
      # Disable CWSR to prevent MES firmware hangs (hard lockups) on GFX11.
      # Broken CWSR saturates the MES ring buffer → WAIT_REG_MEM timeout → full freeze.
      # Regression in kernel 6.18+, no upstream fix as of 6.19.9.
      # Track: https://gitlab.freedesktop.org/drm/amd/-/issues/5092
      #        https://gitlab.freedesktop.org/drm/amd/-/issues/4941
      #        https://github.com/ROCm/ROCm/issues/5844  (gfx1152-specific, our exact GPU)
      # Pending fix: TLB fence rework by Alex Deucher, targeting next kernel release:
      #   https://lore.kernel.org/amd-gfx/20260316151636.1122226-1-alexander.deucher@amd.com/
      #
      # MT7925 Wi-Fi 7: disable PCIe ASPM on the wifi device to avoid hard hangs.
      # The mt7925e driver has documented NULL-ptr-deref / stability bugs that
      # produce instant lockups with no journal trace (kernel never flushes).
      # Symptom seen 2026-05-18: journal cuts mid-line at 07:38:07, ~50s gap,
      # reboot at 07:38:55, no panic / OOM / MCE recorded.
      # Track: https://community.frame.work/t/tracking-kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301
      #        https://bugs.launchpad.net/bugs/2118755  (6 GHz instability)
      #        https://github.com/zbowling/mt7925       (11 fix patches, Jan 2026)
      boot.kernelParams = [
        "amdgpu.dcdebugmask=0x10"
        "amdgpu.cwsr_enable=0"
        "mt7925e.disable_aspm=1"
        # MT7925 crash mitigation + resilience (see block below):
        "cfg80211.ieee80211_regdom=CA" # real regdom (Canada), not world "00" (forces conservative/passive scan)
        "panic=10" # a panic auto-reboots in 10s instead of freezing forever
        "printk.always_kmsg_dump=1" # dump full kernel log to pstore on panic, so we capture the next one
      ];

      # ── MT7925 crash resilience & mitigation (belt-and-suspenders under the pin) ──
      # The kernel-7.0.6 pin above is the actual fix; this block is defence in depth
      # in case a hard-lock ever recurs (e.g. firmware-triggered — the pin downgrades
      # the kernel, NOT the linux-firmware blob). CRASH SIGNATURE, captured via
      # efi-pstore (/var/lib/systemd/pstore; the journal never flushed it — the box
      # froze at the BUG). 4 panics on 7.1.1, Jun 28–Jul 1 (one only 7 min after boot):
      #   kernel BUG at lib/list_debug.c:32        (list_add corruption / double-add)
      #   RIP: __list_add_valid_or_report          Comm: napi/phy0-0
      #     mt7925_mac_add_txs.part.0  [mt7925_common]   (also seen: mt7925_mac_tx_free)
      #     mt7925_rx_check            [mt7925_common]
      #     mt792x_poll_rx             [mt792x_lib]       ← NAPI RX poll
      # Root cause is the 7.1 mt7925 MLO/station-teardown RCU-lifetime race described
      # in the boot.kernelPackages comment above (mt76_wcid_init re-inits a poll_list
      # the RX path already linked); the fix (20b126920a25) is only in v7.2-rc1. The
      # crash-site code is byte-identical 7.0.6↔7.1.1, so this is NOT a mac-path logic
      # bug — pinning to pre-7.1 removes the trigger. Trackers / references:
      #     https://github.com/torvalds/linux/commit/20b126920a25    (THE FIX: "add wcid publish check in mt76_sta_add"; in v7.2-rc1 only, no stable backport)
      #     https://lkml.org/lkml/2026/1/3/61                       (Sean Wang: mt7925 comprehensive stability series, upstream review)
      #     https://github.com/zbowling/mt7925                      (out-of-tree patchset: wcid double-init race, MLO nullptr, mutex guards)
      #     https://zbowling.github.io/mt7925/issues/known-issues/  (symptom catalogue: nullptr in VIF iter, reset-path deadlock)
      #     https://github.com/burakgon/mt7925-wifi-patches         (alternate patchset, tested on Filogic 360)
      #     https://community.frame.work/t/mt7925-wifi-driver-fixes-now-available-as-dkms-package/79777 (prebuilt DKMS)
      #     https://github.com/openwrt/openwrt/issues/16273         (same crash class: kernel panic in mt7925 mac path)
      #     https://community.frame.work/t/tracking-kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301 (main tracking thread)
      #
      # Until the driver is patched, the strategy is: (1) generic hygiene, (2) auto-
      # recover so a lock-up is a ~15s reboot instead of a dead laptop. Capture already
      # works — efi-pstore is built in (CONFIG_EFI_VARS_PSTORE=y) and systemd-pstore
      # (NixOS default) archives each dump to /var/lib/systemd/pstore on the next boot;
      # printk.always_kmsg_dump=1 above just makes it dump the full ring buffer.

      # (1) Generic mt7925 hygiene. NOTE: a TXS logic bug can't be "configured away" —
      # these don't fix the panic, they're documented-good and harmless defaults:
      #   - a real regulatory domain (CA, via kernelParams above) instead of world "00",
      #     which forces conservative/passive scanning; needs the regdb present:
      hardware.wirelessRegulatoryDatabase = true;
      #   - disable NetworkManager Wi-Fi power-save (documented mt7925 crash path):
      networking.networkmanager.wifi.powersave = false;

      # (2) Auto-recovery — the real protection until the driver is patched:
      #   - the panic auto-reboots in 10s (panic=10 in kernelParams above);
      #   - and if a future fault instead wedges the box hard (no panic), arm the SP5100
      #     TCO hardware watchdog (/dev/watchdog here) via systemd: if the kernel can't
      #     pet it within the window, the chip resets the machine on its own.
      systemd.settings.Manager.RuntimeWatchdogSec = "30s";
      systemd.settings.Manager.RebootWatchdogSec = "10s";

      # ── MT7925 + WPA3/SAE: phone-hotspot association failures ──────────────────
      # NOT a crash — a connectivity regression, documented here because it's the same
      # card. From ~Jul 2 2026 this laptop could no longer join the Pixel 10 hotspot
      # ("JevyPixel"): wpa_supplicant looped forever, never associating —
      #   SME: Trying to authenticate ... (SSID='JevyPixel')
      #   CTRL-EVENT-AUTH-REJECT auth_type=3 auth_transaction=2 status_code=15   (×24/attempt)
      #   NetworkManager: (wifi) association took too long, failing activation
      # auth_type=3 = SAE (WPA3); rejection at the SAE *confirm* (transaction 2) with
      # the generic status 15 = the AP threw out the handshake. Never associated → no
      # DHCP/DNS, so it presents as "internet down". WPA2-only APs (e.g. hotels) connect
      # instantly because they never exercise the SAE path.
      #
      # NOT the laptop's fault (verified 2026-07-03 against the journal + flake.lock):
      # the identical stack CONNECTED fine to this hotspot on Jun 5 & Jun 12 (kernel
      # 7.0.6) and Jun 19 (7.1.1), then failed from Jul 2 with NOTHING changed on our
      # side — linux-firmware byte-identical (3pskh1jw…-linux-firmware-20260519, same
      # store path before & after the Jun 27 input bump), wpa_supplicant 2.11 and
      # NetworkManager 1.56.0 unchanged, and 7.0.6 already proven-good above. The moving
      # part is the *phone*: Pixel 10 / Android 16 shipped a WPA3-SAE behaviour change
      # mid-2026 (OpenWrt #21485 documents the Pixel 10/Android 16 SAE regression),
      # meeting a card widely reported weak on WPA3 but solid on WPA2. Two fragile SAE
      # endpoints — a phone-side change tipped it from "works" to "broken".
      #
      # FIX (imperative, per-connection — deliberately NOT declared here: the profile
      # carries the hotspot PSK, which does not belong in the repo). Disable PMF on the
      # saved connection; WPA3-SAE mandates PMF, so turning it off removes SAE from the
      # menu and forces the compatible WPA2-PSK path the phone still offers in
      # transition mode:
      #     nmcli connection modify JevyPixel 802-11-wireless-security.pmf 1   # 1 = disable
      #     (revert with `… pmf 0`)   Applied 2026-07-03; community-standard fix for this class.
      # Same pmf-disable applies per-network if other WPA3 hotspots start failing;
      # last-resort escapes others use: switch wpa_supplicant↔iwd, or swap in an Intel card.
      # Refs: https://github.com/openwrt/openwrt/issues/21485                              (Pixel 10 / Android 16 WPA3-SAE regression)
      #       https://community.frame.work/t/issues-with-mediatek-mt7925-rz717-wi-fi-card/75815 (MT7925: WPA3 unstable, WPA2 solid)
      #       https://sageaxe.com/troubleshoot/wpa3-transition-issues                       (WPA3 transition-mode fixes: disable PMF / force WPA2)

      # AMD GPU and OLED/touch support
      boot.kernelModules = [ "i2c-dev" ];

      # ── xdg-desktop-portal vs the CVE-2026-46333 ptrace hardening ──────────────
      # The kernel fix for CVE-2026-46333 ("ptrace: slightly saner get_dumpable()
      # logic", commit 31e62c2ebbfd, ~2026-05) tightened ptrace_may_access(): opening
      # another process's /proc/<pid>/root now requires CAP_SYS_PTRACE even for a
      # same-uid, *dumpable* target. That fix is backported into the pinned 7.0.6 above
      # (so 7.0.6 is NOT free of the "portal regression" the kernel comment hoped —
      # it's a different, security-driven tightening, not the earlier pidfd bug).
      #
      # xdg-desktop-portal 1.20.4 resolves a caller's app-info by doing exactly that
      # open, runs with no capabilities, and treats the resulting EACCES as fatal:
      #     openat("/proc/<pid>/root", O_DIRECTORY) = -1 EACCES
      #     → "Portal operation not allowed: Unable to open /proc/<pid>/root"
      # so it denies EVERY interactive request — screen sharing AND the GTK file
      # chooser silently do nothing in Slack, Firefox, etc. Confirmed by straceing the
      # portal and reproducing the open from a cap-empty uid-1000 process (fails) vs a
      # process holding any effective capability (succeeds). ptrace_scope is irrelevant.
      #
      # No clean escape exists yet: nixpkgs (incl. unstable) is still on portal 1.20.4,
      # and no kernel carries both this CVE fix done right *and* the MT7925 BT fix.
      # So: hand the portal exactly the capability the kernel now demands, and nothing
      # more. A security.wrappers setcap shim raises CAP_SYS_PTRACE (ambient) then execs
      # the real binary; the portal's user unit is pointed at the shim via a drop-in.
      # Blast radius is one daemon — no system-wide hardening is relaxed (cf. the
      # ptrace_scope=0 dead-end, which did nothing because this isn't the Yama gate).
      # Remove this whole block once nixpkgs ships a portal that treats the failed
      # /proc open as "host app" instead of fatal. See CVE: https://nvd.nist.gov/vuln/detail/CVE-2026-46333
      security.wrappers.xdg-desktop-portal-ptrace = {
        owner = "root";
        group = "root";
        capabilities = "cap_sys_ptrace+ep";
        source = "${pkgs.xdg-desktop-portal}/libexec/xdg-desktop-portal";
      };
      # Point the portal's user service at the capability shim (the D-Bus service file
      # activates via SystemdService=xdg-desktop-portal.service, so this override takes).
      # Must be a real systemd drop-in (overrideStrategy = "asDropin"); environment.etc
      # can't write under /etc/systemd/user, which NixOS manages as a read-only tree.
      systemd.user.services.xdg-desktop-portal = {
        overrideStrategy = "asDropin";
        serviceConfig.ExecStart = [
          "" # reset the package unit's ExecStart, then point at the cap shim
          "/run/wrappers/bin/xdg-desktop-portal-ptrace"
        ];
      };

      # Ensure all firmware blobs available (MediaTek MT7925, AMD GPU, etc.)
      hardware.enableRedistributableFirmware = true;

      # Firmware updates (ThinkPad support)
      services.fwupd.enable = true;
      services.upower.enable = true;

      # Fingerprint reader
      services.fprintd.enable = true;

      # Power management (AMD PPD instead of Intel thermald)
      services.power-profiles-daemon.enable = true;
      environment.systemPackages = [ pkgs.powertop ];
      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 30;
      };

      # DDC for external monitor brightness control
      services.ddccontrol.enable = true;
      hardware.i2c.enable = true;
      services.udev.extraRules = ''
        KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
        # Prevent USB autosuspend for Synaptics fingerprint reader — avoids
        # extra delay when the sensor is woken after long idle.
        # https://github.com/hyprwm/hyprlock/issues/702
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="06cb", ATTR{idProduct}=="00f9", ATTR{power/autosuspend}="-1"
        # Prevent USB autosuspend for Focusrite Scarlett Solo and its parent
        # Realtek hub — the hub's aggressive autosuspend (0ms) causes the
        # Scarlett to disconnect on resume and WirePlumber fails to reconfigure it.
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1235", ATTR{idProduct}=="8205", ATTR{power/autosuspend}="-1"
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5411", ATTR{power/autosuspend}="-1"
      '';

      # Allow the user's micMuteAll script to control the mic mute LED
      # directly via sysfs, bypassing the ctl-led mechanism which gets
      # reset by WirePlumber on startup.
      systemd.services.fix-micmute-led = {
        description = "Set up mic mute LED for direct user control";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "fix-micmute-led" ''
            LED=/sys/class/leds/platform::micmute
            [ -d "$LED" ] || exit 0
            echo none > "$LED/trigger"
            chmod 666 "$LED/brightness"
          '';
        };
      };

      # Auto-recover the AMD xHCI controller (0000:c4:00.4, PCI 1022:1128)
      # when it wedges on s2idle resume. Roughly 1-in-N resumes the controller
      # fails to come back with:
      #   xhci_hcd 0000:c4:00.4: xHCI host not responding to stop endpoint command
      #   xhci_hcd 0000:c4:00.4: xHCI host controller not responding, assume dead
      #   xhci_hcd 0000:c4:00.4: HC died; cleaning up
      #   usb 1-1: PM: failed to resume async: error -22
      # Bus 1 is then dead until reboot — the integrated RGB camera
      # (30c9:00f4) sits on that bus, so the webcam disappears.
      #
      # Open Strix/Krackan-Point xHCI resume bug, still unfixed in mainline
      # as of kernel 6.18/6.19. The earlier xHCI cycle-bit fix (c7c1f3b05c67,
      # in 6.13.7) does NOT cover this case. No matching xhci_hcd quirk for
      # PCI ID 1022:1128 has landed.
      # Track: https://community.frame.work/t/workaround-xhci-host-controller-not-responding-at-resume-after-suspend/79119
      #        https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/163
      #        https://lkml.org/lkml/2025/8/20/1155
      #
      # Workaround: hot-remove and rescan the PCI device, which re-initializes
      # the xHCI controller and re-enumerates bus 1. Verified locally
      # 2026-05-19: `/dev/video*` reappears within ~3s, no reboot needed.
      systemd.services.xhci-resume-rescue = {
        description = "Auto-recover wedged AMD xHCI 0000:c4:00.4 after resume";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-journald.service" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "5s";
          ExecStart = pkgs.writeShellScript "xhci-resume-rescue" ''
            set -u
            DEV=0000:c4:00.4
            ${pkgs.systemd}/bin/journalctl -kf -o cat --since=now \
              | while IFS= read -r line; do
                  case "$line" in
                    *"$DEV"*"HC died"*)
                      if [ -e /sys/bus/pci/devices/$DEV ]; then
                        echo "xhci-resume-rescue: HC died on $DEV — removing and rescanning"
                        echo 1 > /sys/bus/pci/devices/$DEV/remove
                        sleep 2
                        echo 1 > /sys/bus/pci/rescan
                      fi
                      ;;
                  esac
                done
          '';
        };
      };

      # Keyboard and peripheral support (ZSA, QMK — same as framework)
      hardware.keyboard.zsa.enable = true;
      services.udev.packages = with pkgs; [ via qmk-udev-rules ];
    };
}
