# IR camera facial recognition (Howdy + linux-enable-ir-emitter)
#
# After rebuild, run these one-time setup steps:
#
#   1. Find the IR camera device (confirm it's video2):
#        v4l2-ctl --list-devices
#      If it's not video2, update `device` and `device_path` below, then rebuild.
#
#   2. Configure the IR emitter (interactive — probes UVC controls):
#        sudo linux-enable-ir-emitter configure
#      This saves config that auto-restores on boot and after suspend.
#
#   3. Enroll your face:
#        sudo howdy add
#
#   4. Test it:
#        sudo howdy test          # live camera feed with face detection overlay
#        sudo -k && sudo echo ok  # test actual PAM auth
#
# Notes:
#   - Howdy works alongside fprintd — PAM tries both, either unlocks.
#   - Howdy is a convenience feature, not a security upgrade. Keep password as fallback.
#   - Known issue: howdy is incompatible with polkit-127 (sudo works, GUI auth may not).
#     Track: https://github.com/nixos/nixpkgs/issues/483867
#
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
