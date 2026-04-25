# Ham radio services: SDRplay API, hamlib/rigctld, WSJT-X, SparkSDR
# rigctld owns /dev/ic7300 and exposes hamlib protocol on TCP :4532
# Remote clients (flrig, grig) connect via hamlib NET rigctl (model 2)
{ inputs, ... }:
{
  flake.modules.nixos.hamRadio =
    { pkgs, lib, config, ... }:
    let
      sparksdr = pkgs.callPackage ../../pkgs/sparksdr.nix { };
    in
    {
      # ── SDRplay API service ──────────────────────────────────────────
      services.sdrplayApi.enable = true;

      # Block SDRplay telemetry (sends device serial numbers unencrypted)
      networking.hosts = { "0.0.0.0" = [ "api.sdrplay.com" ]; };

      # Blacklist kernel modules that conflict with sdrplay_apiService
      boot.blacklistedKernelModules = [ "sdr_msi3101" "msi001" "msi2500" ];

      # ── udev rules ──────────────────────────────────────────────────
      services.udev.extraRules = ''
        # Icom IC-7300 USB serial (Silicon Labs CP210x)
        SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="ic7300", MODE="0660", GROUP="dialout"
        # Icom IC-7300 USB audio codec
        SUBSYSTEM=="sound", ATTRS{idVendor}=="08bb", ATTRS{idProduct}=="2901", ATTR{id}="IC7300"
      '';

      # ── Packages ─────────────────────────────────────────────────────
      environment.systemPackages = with pkgs; [
        hamlib_4      # rigctld, rigctl
        wsjtx         # WSJT-X for WSPR/FT8
        tqsl          # ARRL Logbook of the World
        sparksdr      # SparkSDR for RSPduo multi-band monitoring
        sdrplay       # SDRplay API libraries
        vlc           # Media player for audio monitoring
      ];

      # ── rigctld — IC-7300 rig control daemon ─────────────────────────
      # Owns /dev/ic7300, exposes hamlib protocol on TCP :4532
      # Supports multiple simultaneous clients (WSJT-X, remote grig/flrig)
      systemd.services.rigctld = {
        description = "Hamlib rigctld for IC-7300";
        after = [ "dev-ic7300.device" ];
        bindsTo = [ "dev-ic7300.device" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.hamlib_4}/bin/rigctld --model=3073 --rig-file=/dev/ic7300 --serial-speed=115200 --port=4532 --set-conf=rts_state=OFF --set-conf=dtr_state=OFF";
          Restart = "on-failure";
          RestartSec = 5;
          User = "jevin";
          Group = "dialout";
        };
      };

      # ── PipeWire network audio ──────────────────────────────────────
      # Expose IC-7300 USB audio over the network for remote monitoring
      services.pipewire.extraConfig.pipewire-pulse."30-network" = {
        "pulse.cmd" = [
          { cmd = "load-module"; args = "module-native-protocol-tcp auth-anonymous=1"; }
          { cmd = "load-module"; args = "module-zeroconf-publish"; }
        ];
      };

      # ── SparkSDR — RSPduo multi-band WSPR/FT8 skimmer ──────────────
      # Uncomment once SparkSDR profile is configured
      # systemd.services.sparksdr = {
      #   description = "SparkSDR WSPR/FT8 skimmer (RSPduo)";
      #   after = [ "network-online.target" "sdrplay-api.service" ];
      #   wants = [ "network-online.target" "sdrplay-api.service" ];
      #   wantedBy = [ "multi-user.target" ];
      #   serviceConfig = {
      #     ExecStart = "${sparksdr}/bin/sparksdr-headless";
      #     Restart = "on-failure";
      #     RestartSec = 10;
      #     User = "jevin";
      #     Group = "dialout";
      #     SupplementaryGroups = [ "audio" ];
      #   };
      # };

      # ── Firewall ─────────────────────────────────────────────────────
      networking.firewall.allowedTCPPorts = [
        4532  # rigctld (hamlib protocol)
        4649  # SparkSDR WebSocket
      ];
    };
}
