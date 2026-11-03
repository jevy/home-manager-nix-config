# Ham radio services: SDRplay API, WSJT-X, SparkSDR, SDR servers
# The IC-7300 itself is owned by wfview (modules/services/wfview.nix), which
# serves hamlib's rigctld protocol on TCP :4532 for WSJT-X, wlgate and
# remote rigctl/flrig/grig clients (hamlib NET rigctl, model 2).
{ inputs, ... }:
{
  flake.modules.nixos.hamRadio =
    { pkgs, lib, config, ... }:
    let
      sparksdr = pkgs.callPackage ../../pkgs/sparksdr.nix { };

      # Interactive (FT8) WSJT-X for the laptop's `ic7300` alias. Pins the
      # audio devices in ~/.config/WSJT-X.ini to the ic7300-rx/-tx virtual
      # devices (see "IC-7300 audio" below) and CAT to wfview's :4532 before
      # launching, and clears stale shared memory a killed WSJT-X leaves
      # behind. The beacon itself is stopped/started by the alias, which has
      # sudo over ssh.
      wsjtxIc7300 = pkgs.writeShellScriptBin "wsjtx-ic7300" ''
        ini="$HOME/.config/WSJT-X.ini"
        if [ -f "$ini" ]; then
          ${pkgs.gnused}/bin/sed -i \
            -e 's/^SoundInName=.*/SoundInName=ic7300-rx/' \
            -e 's/^SoundOutName=.*/SoundOutName=ic7300-tx/' \
            -e 's/^CATNetworkPort=.*/CATNetworkPort=localhost:4532/' "$ini"
        fi
        rm -rf /tmp/WSJT-X.lock /tmp/qipc_sharedmemory_*WSJT* /tmp/qipc_systemsem_*WSJT* 2>/dev/null
        export QT_SCALE_FACTOR=''${QT_SCALE_FACTOR:-2} QT_XCB_GL_INTEGRATION=none
        exec ${pkgs.wsjtx}/bin/wsjtx "$@"
      '';
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
        wsjtxIc7300           # FT8 launcher (laptop `ic7300` alias), see let above
        hamlib_4              # rigctl CLI (talks to wfview's rigctld emulation)
        wsjtx                 # WSJT-X for WSPR/FT8
        js8call               # JS8Call — keyboard chat over FT8-like protocol
        fldigi                # Olivia, PSK31, MFSK, RTTY, Hellschreiber, etc.
        gridtracker           # Live WSJT-X decode map
        flrig                 # Rig control GUI used by fldigi/wsjtx
        tqsl                  # ARRL Logbook of the World
        sparksdr              # SparkSDR for RSPdx multi-band monitoring
        sdrpp                 # SDR++ — fast minimal panadapter, --server mode
        sdrangel              # SDRangel — kitchen-sink with web UI
        cubicsdr              # CubicSDR — Soapy-based panadapter
        sdrplay               # SDRplay API libraries
        soapysdr-with-plugins # SoapyAPI + SDRplay plugin (overlay)
        vlc                   # Media player for audio monitoring
        pavucontrol           # PulseAudio/PipeWire volume + stream routing
        qpwgraph              # PipeWire graph patchbay (visual JACK-style routing)
      ];

      # (rigctld used to live here; wfview.nix now owns /dev/ic7300 and
      # emulates rigctld on :4532. hamlib_4 stays above for the rigctl CLI.)

      # ── IC-7300 audio through PipeWire, shared ──────────────────────
      # Every app uses two stable virtual devices instead of the codec
      # (PCM2901, "USB Audio CODEC") itself:
      #
      #   7300 RX ─ alsa_input.usb-Burr-Brown… ─▶ ic7300-rx  (source, mono)
      #   7300 TX ◀ alsa_output.usb-Burr-Brown… ◀─ ic7300-tx (sink, mono)
      #
      #   ic7300-rx ─▶ WSJT-X / JS8Call decode, wfview server (laptop audio),
      #                laptop `ic7300-listen` (pulse over TCP, below)
      #   ic7300-tx ◀─ WSJT-X / JS8Call TX, wfview server (laptop mic)
      #
      # Pulse/Qt5 apps pick them by node.name (ic7300-rx/-tx), wfview by
      # description prefix ("IC-7300 RX"/"IC-7300 TX").
      #
      # Why the loopbacks are not passive: they keep PipeWire holding the
      # codec open whenever the radio is on. WSJT-X (Qt5) probes every raw
      # ALSA device at startup ("pcm_dmix ... unable to open slave"); while
      # the capture side was suspended that probe grabbed it, PipeWire's own
      # open failed with EBUSY and WirePlumber dropped the input node until
      # restarted (2026-11-01 16:27: no RX in WSJT-X, silent laptop). With
      # PipeWire holding both directions the probe just gets EBUSY itself.
      # dont-fallback: radio off means silence, not the built-in mic/speaker.
      services.pipewire.extraConfig.pipewire."60-ic7300" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "IC-7300 RX";
              "capture.props" = {
                "node.name" = "ic7300-rx.hw";
                "target.object" = "alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo";
                "audio.position" = [ "FL" "FR" ];
                "node.dont-fallback" = true;
                "stream.dont-remix" = false;
              };
              "playback.props" = {
                "node.name" = "ic7300-rx";
                "media.class" = "Audio/Source";
                "priority.session" = 2100;
                "audio.position" = [ "MONO" ];
              };
            };
          }
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "IC-7300 TX";
              "capture.props" = {
                "node.name" = "ic7300-tx";
                "media.class" = "Audio/Sink";
                "priority.session" = 2100;
                "audio.position" = [ "MONO" ];
              };
              "playback.props" = {
                "node.name" = "ic7300-tx.hw";
                "target.object" = "alsa_output.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo";
                "audio.position" = [ "FL" "FR" ];
                "node.dont-fallback" = true;
              };
            };
          }
        ];
      };

      # Hardware side never suspends. (The virtual devices win "default" via
      # priority.session above, so anything left on "default" hits the radio.)
      services.pipewire.wireplumber.extraConfig."50-ic7300" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC*"; }
              { "node.name" = "~alsa_output.usb-Burr-Brown_from_TI_USB_Audio_CODEC*"; }
            ];
            actions.update-props."session.suspend-timeout-seconds" = 0;
          }
        ];
      };

      # ── PipeWire network audio ──────────────────────────────────────
      # Expose IC-7300 audio over the network: the laptop's `ic7300-listen`
      # plays ic7300-rx from here (listen only, no TX, beacon keeps running).
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
        4649  # SparkSDR WebSocket
        4713  # pulse TCP (laptop `ic7300-listen`)
        5259  # SDR++ IQ server
        8091  # SDRangel web UI / REST API
      ];
    };
}
