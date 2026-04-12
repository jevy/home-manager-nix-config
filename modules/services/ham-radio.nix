# Ham radio services: SDRplay API, wfview/wfserver, hamlib/rigctld, WSJT-X, SparkSDR
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
        SUBSYSTEM=="sound", ATTRS{idVendor}=="08bb", ATTRS{idProduct}=="2904", ATTR{id}="IC7300"
      '';

      # ── Packages ─────────────────────────────────────────────────────
      environment.systemPackages = with pkgs; [
        hamlib_4      # rigctld, rigctl
        wfview        # wfview GUI + wfserver headless
        wsjtx         # WSJT-X for WSPR/FT8
        sparksdr      # SparkSDR for RSPduo multi-band monitoring
        sdrplay       # SDRplay API libraries
      ];

      # ── rigctld — IC-7300 rig control daemon ─────────────────────────
      # Exposes IC-7300 control on TCP :4532 for wfview/WSJT-X/SparkSDR
      # Uncomment once hardware config is confirmed (serial device path)
      # systemd.services.rigctld = {
      #   description = "Hamlib rigctld for IC-7300";
      #   after = [ "dev-ic7300.device" ];
      #   bindsTo = [ "dev-ic7300.device" ];
      #   wantedBy = [ "multi-user.target" ];
      #   serviceConfig = {
      #     ExecStart = "${pkgs.hamlib_4}/bin/rigctld --model=3073 --rig-file=/dev/ic7300 --serial-speed=115200 --port=4532 --set-conf=rts_state=OFF --set-conf=dtr_state=OFF";
      #     Restart = "on-failure";
      #     RestartSec = 5;
      #     User = "jevin";
      #     Group = "dialout";
      #   };
      # };

      # ── wfserver — remote rig control + audio over network ──────────
      # Provides full IC-7300 control + audio streaming over Tailscale
      # Also emulates rigctld on :4533 so WSJT-X/SparkSDR can share the radio
      # Uncomment once wfserver.ini is configured
      # systemd.services.wfserver = {
      #   description = "wfview headless server for IC-7300";
      #   after = [ "network-online.target" "dev-ic7300.device" ];
      #   wants = [ "network-online.target" ];
      #   bindsTo = [ "dev-ic7300.device" ];
      #   wantedBy = [ "multi-user.target" ];
      #   serviceConfig = {
      #     ExecStart = "${pkgs.wfview}/bin/wfserver";
      #     Restart = "on-failure";
      #     RestartSec = 10;
      #     User = "jevin";
      #     Group = "dialout";
      #     SupplementaryGroups = [ "audio" ];
      #   };
      # };

      # ── SparkSDR — RSPduo multi-band WSPR/FT8 skimmer ──────────────
      # Runs under xvfb (no display needed), spots uploaded to PSKReporter
      # WebSocket control interface on :4649
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
        4532  # rigctld
        4533  # wfview rigctld emulation
        4649  # SparkSDR WebSocket
      ];
    };
}
