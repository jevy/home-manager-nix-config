# Shared base for all headless Linux server hosts
{ config, inputs, ... }:
let
  inherit (config.flake.modules) nixos homeManager;
in
{
  flake.modules.nixos.linuxServerBase =
    { pkgs, lib, ... }:
    {
      imports = [
        nixos.nix
        nixos.user
        nixos.zsh
        nixos.tailscale
        nixos.network

        inputs.home-manager.nixosModules.home-manager
      ];

      nixpkgs.config.allowUnfree = true;

      system.stateVersion = "24.11";

      # Headless boot — systemd-boot, no GUI
      boot.loader.systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_6_12;

      # Timezone
      time.timeZone = "America/Toronto";
      services.timesyncd = {
        enable = true;
        servers = [ "0.ca.pool.ntp.org" "1.ca.pool.ntp.org" ];
      };

      # SSH server
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      # Prometheus node exporter — scrape at http://shop-sdr:9100/metrics
      services.prometheus.exporters.node = {
        enable = true;
        enabledCollectors = [ "systemd" "processes" ];
        port = 9100;
      };
      # Only allow node exporter over Tailscale (not exposed to LAN)
      networking.firewall.allowedTCPPorts = [ 9100 ];

      # DBus
      services.dbus.enable = true;

      # Zsh system-wide
      programs.zsh.enable = true;

      # Home-manager integration
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        users.jevin = {
          imports = [
            homeManager.zsh
            homeManager.sops
            homeManager.git
            homeManager.cliBase
            homeManager.nixvim
            homeManager.ssh
          ];

          home.stateVersion = "24.11";
        };
      };
    };
}
