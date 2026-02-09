# User definition for NixOS systems
{ ... }:
{
  flake.modules.nixos.user =
    { pkgs, lib, ... }:
    {
      users.mutableUsers = false;

      users.users.jevin = {
        shell = pkgs.zsh;
        isNormalUser = true;
        extraGroups = [
          "qemu-libvirtd"
          "libvirtd"
          "plugdev"
          "wheel"
          "networkmanager"
          "docker"
          "dialout"
          "audio"
          "video"
          "adbusers"
          "uinput"
          "i2c"
          "input"
        ];

        # `nix-shell -p mkpasswd --run 'mkpasswd -m sha-512'`
        hashedPassword = "$6$RQ3xn2S3O1RFFqiA$e725RMH8eJgw4JJ4UnSjuzJ1Pw5lNNaFRW.9M2XCrcCJsAbWPg5qs5hzRZARiK9uastNZN9XnUGBs8yM6kdMZ0";
      };

      security.sudo.wheelNeedsPassword = false;
    };
}
