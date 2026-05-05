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
      # Only one client can own the RSPdx via the SDRplay API at a time.
      # SparkSDR runs interactively from the RDP session; sdrpp-server /
      # sdrangel-server are headless user units (below) for ad-hoc remote
      # tuning. Quit SparkSDR before starting either server unit.
      environment.systemPackages = with pkgs; [
        hamlib_4              # rigctld, rigctl
        wsjtx                 # WSJT-X for WSPR/FT8
        gridtracker           # Live WSJT-X decode map
        grig                  # Hamlib rig control GUI
        flrig                 # Rig control GUI used by fldigi/wsjtx
        tqsl                  # ARRL Logbook of the World
        sparksdr              # SparkSDR for RSPdx multi-band monitoring
        sdrpp                 # SDR++ — fast minimal panadapter, --server mode
        sdrangel              # SDRangel — kitchen-sink with web UI
        cubicsdr              # CubicSDR — Soapy-based panadapter
        sdrplay               # SDRplay API libraries
        soapysdr-with-plugins # SoapyAPI + SDRplay plugin (overlay)
        vlc                   # Media player for audio monitoring
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

      # SparkSDR runs interactively from the RDP session (Applications
      # menu → SparkSDR). xrdp-sesman keeps the session alive across
      # disconnect, so the GUI stays running with all receivers active
      # until reboot or explicit quit. RSPdx is single-tuner — quit
      # SparkSDR before starting sdrpp-server / sdrangel-server below.

      # Keep jevin's user systemd manager alive at boot so the sdrpp /
      # sdrangel server units below can be controlled from an SSH login
      # without first opening an RDP session.
      systemd.tmpfiles.rules = [ "f /var/lib/systemd/linger/jevin 0644 root root - -" ];

      # ── SDR++ server — minimal panadapter for remote tuning ────────
      # Stream IQ to a local sdrpp client on the laptop (default port 5259).
      # Manual start: `systemctl --user start sdrpp-server`. Make sure
      # SparkSDR is quit first — both want exclusive access to the RSPdx.
      systemd.user.services.sdrpp-server = {
        description = "SDR++ headless IQ server (RSPdx)";
        after = [ "pipewire.service" ];
        wants = [ "pipewire.service" ];
        wantedBy = [ ];
        conflicts = [ "sdrangel-server.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.sdrpp}/bin/sdrpp --server --addr 0.0.0.0 --port 5259";
          Restart = "on-failure";
          RestartSec = 10;
        };
      };

      # ── SDRangel server — web UI on :8091, REST API ────────────────
      # Browse to http://shop-sdr:8091/ to drive it. Heaps of demods/decoders.
      # Manual start: `systemctl --user start sdrangel-server`. Quit
      # SparkSDR first — both want exclusive access to the RSPdx.
      systemd.user.services.sdrangel-server = {
        description = "SDRangel headless server with web UI (RSPdx)";
        after = [ "pipewire.service" ];
        wants = [ "pipewire.service" ];
        wantedBy = [ ];
        conflicts = [ "sdrpp-server.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.sdrangel}/bin/sdrangelsrv --api-address 0.0.0.0 --api-port 8091";
          Restart = "on-failure";
          RestartSec = 10;
        };
      };

      # ── Firewall ─────────────────────────────────────────────────────
      networking.firewall.allowedTCPPorts = [
        4532  # rigctld (hamlib protocol)
        4649  # SparkSDR WebSocket
        5259  # SDR++ IQ server
        8091  # SDRangel web UI / REST API
      ];
    };
}
