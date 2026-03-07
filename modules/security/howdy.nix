# IR camera facial recognition (Howdy + linux-enable-ir-emitter)
{ ... }:
{
  flake.modules.nixos.howdy =
    { ... }:
    {
      # Enable IR emitter (ThinkPad IR LEDs are off by default on Linux)
      services.linux-enable-ir-emitter = {
        enable = true;
        device = "video2"; # verify with: v4l2-ctl --list-devices
      };

      # Howdy facial recognition via PAM
      services.howdy = {
        enable = true;
        settings = {
          video = {
            device_path = "/dev/video2";
            dark_threshold = 80;
          };
        };
      };
    };
}
