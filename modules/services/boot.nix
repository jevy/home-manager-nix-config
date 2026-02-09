# Boot, timezone, and system basics
{ ... }:
{
  flake.modules.nixos.boot =
    { pkgs, ... }:
    {
      # Location for services like redshift/wlsunset
      location = {
        latitude = 45.42;
        longitude = -75.70;
      };

      # Boot configuration
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 20;
      };
      boot.loader.efi.canTouchEfiVariables = true;
      boot.supportedFilesystems = [ "zfs" "nfs" ];
      boot.initrd.luks.devices = {
        root = {
          device = "/dev/nvme0n1p1";
          preLVM = true;
        };
      };
      boot.kernelPackages = pkgs.linuxPackages_6_12;

      # Time
      time.timeZone = "America/Toronto";
      services.timesyncd = {
        enable = true;
        servers = [ "0.ca.pool.ntp.org" "1.ca.pool.ntp.org" ];
      };

      # Automount drives
      services.devmon.enable = true;
      services.gvfs.enable = true;
      services.udisks2.enable = true;
      services.udisks2.mountOnMedia = true;

      # DBus
      services.dbus.enable = true;

      # GPG agent
      programs.gnupg.agent.enable = true;

      # Zsh (required before user can use it)
      programs.zsh.enable = true;

      # System packages
      environment.systemPackages = [
        pkgs.adwaita-icon-theme
        pkgs.shared-mime-info
        pkgs.android-tools
      ];
      environment.pathsToLink = [ "/share/icons" "/share/mime" ];
    };
}
