# Audio configuration (PipeWire, Bluetooth)
{ ... }:
{
  # NixOS audio configuration
  flake.modules.nixos.audio =
    { ... }:
    {
      hardware.bluetooth.enable = true;

      services.pulseaudio = {
        enable = false;
        daemon.config = {
          flat-volumes = "no";
        };
      };

      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        pulse.enable = true;
        jack.enable = true;
      };

      # Audio device priority configuration
      # Scarlett > QC35 Bluetooth > Laptop speakers (fallback)
      services.pipewire.wireplumber.extraConfig."51-device-priorities" = {
        # Scarlett USB Audio Interface - highest priority
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_output.usb-Focusrite.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2000;
                "priority.session" = 1400;
              };
            };
          }
          {
            matches = [
              { "node.name" = "~alsa_input.usb-Focusrite.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2500;
                "priority.session" = 2500;
              };
            };
          }
        ];

        # QC35 Bluetooth headphones - second priority
        "monitor.bluez.rules" = [
          {
            matches = [
              { "node.name" = "~bluez_output.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 1800;
                "priority.session" = 1200;
              };
            };
          }
          {
            matches = [
              { "node.name" = "~bluez_input.*"; }
            ];
            actions = {
              update-props = {
                "priority.driver" = 2200;
                "priority.session" = 2200;
              };
            };
          }
        ];
      };
    };

  # Home-manager audio services
  flake.modules.homeManager.audio =
    { ... }:
    {
      services.playerctld.enable = true;
    };
}
