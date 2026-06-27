# Lenovo ThinkPad P14s Gen 6 AMD hardware configuration
{ ... }:
{
  flake.modules.nixos.lenovoP14sHardware =
    { pkgs, ... }:
    {
      # linuxPackages_latest (kernel 7.1.x) for best Zen 5 / RDNA 3.5 / MT7925
      # WiFi 7 support. Previously pinned to 7.0.6 via a separate nixpkgs input to
      # dodge two regressions; that pin is gone now that 7.1 carries the fixes:
      #   - MT7925/MT7922 Bluetooth: btmtk rejected the chip's short WMT FUNC_CTRL
      #     event ("Failed to send wmt func ctrl (-22)", no controller). Broken in
      #     7.0.7 by 634a4408c061, fixed by e193447ac6c9 — merged into the 7.1 base
      #     tree, so 7.1.x has working BT natively.
      #   - The xdg-desktop-portal "/proc/<pid>/root" breakage is NOT a revertable
      #     kernel regression: it's the permanent CVE-2026-46333 get_dumpable
      #     tightening (31e62c2ebbfd), present in both 7.0.6 and 7.1.x. It's handled
      #     by the security.wrappers CAP_SYS_PTRACE shim below, which stays in place
      #     regardless of kernel version (see that block).
      boot.kernelPackages = pkgs.linuxPackages_latest;

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
      ];

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
