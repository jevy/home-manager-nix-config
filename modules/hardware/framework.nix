# Framework laptop hardware configuration
{ ... }:
{
  flake.modules.nixos.frameworkHardware =
    { pkgs, ... }:
    {
      # Intel graphics
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          intel-vaapi-driver
          intel-media-driver
        ];
      };

      # Force probe for Intel GPU
      boot.kernelParams = [ "i915.force_probe=4626" ];
      boot.kernelModules = [
        "i2c-dev"
        "iptable_nat"
        "iptable_filter"
      ];

      # Framework services
      services.fwupd.enable = true;
      services.upower.enable = true;
      services.hardware.bolt.enable = true;

      # DDC for external monitor control
      services.ddccontrol.enable = true;
      hardware.i2c.enable = true;
      services.udev.extraRules = ''
        KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
      '';

      # Keyboard and peripheral support
      hardware.keyboard.zsa.enable = true;
      services.udev.packages = with pkgs; [
        via
        qmk-udev-rules
        qFlipper
      ];

      # Scanner support
      hardware.sane.enable = true;
      hardware.sane.drivers.scanSnap.enable = true;

      # Power management
      services.thermald.enable = true;
      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = 30;
      };
    };
}
