# Lenovo ThinkPad P14s Gen 6 AMD hardware configuration
{ ... }:
{
  flake.modules.nixos.lenovoP14sHardware =
    { pkgs, ... }:
    {
      # AMD graphics
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      # Latest kernel for best Zen 5 / RDNA 3.5 / MT7925 WiFi 7 support
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
      boot.kernelParams = [ "amdgpu.dcdebugmask=0x10" "amdgpu.cwsr_enable=0" ];

      # AMD GPU and OLED/touch support
      boot.kernelModules = [ "i2c-dev" ];

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

      # Keyboard and peripheral support (ZSA, QMK — same as framework)
      hardware.keyboard.zsa.enable = true;
      services.udev.packages = with pkgs; [ via qmk-udev-rules ];
    };
}
