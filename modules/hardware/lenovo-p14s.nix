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
      boot.kernelParams = [ "amdgpu.dcdebugmask=0x10" ];

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
        SUBSYSTEM=="sound", KERNEL=="card[0-9]*", ACTION=="add|change", TAG+="systemd", ENV{SYSTEMD_WANTS}="fix-micmute-led.service"
      '';

      # Re-attach the correct ALSA control for the mic mute LED whenever
      # sound cards appear (boot + hot-plug). The micMuteAll script toggles
      # this ALSA control alongside wpctl to keep the LED in sync.
      systemd.services.fix-micmute-led = {
        description = "Attach mic mute LED to correct ALSA control";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "fix-micmute-led" ''
            for card in /sys/devices/virtual/sound/ctl-led/mic/card*/; do
              [ -d "$card" ] || continue
              num=$(basename "$card" | sed 's/card//')
              if ${pkgs.alsa-utils}/bin/amixer -c "$num" controls 2>/dev/null | grep -q 'Mic ACP LED Capture Switch'; then
                echo 'Capture Switch' > "$card/detach"
                echo 'Mic ACP LED Capture Switch' > "$card/attach"
                exit 0
              fi
            done
          '';
        };
      };

      # Keyboard and peripheral support (ZSA, QMK — same as framework)
      hardware.keyboard.zsa.enable = true;
      services.udev.packages = with pkgs; [ via qmk-udev-rules ];
    };
}
