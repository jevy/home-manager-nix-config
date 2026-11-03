# wfview: owns the IC-7300 and serves it two ways.
#   - rigctld emulation on TCP :4532, so WSJT-X ("Hamlib NET rigctl"),
#     wlgate and `rigctl -m 2 -r shop-sdr:4532` keep working unchanged.
#     It replaces hamlib's rigctld, which used to own /dev/ic7300.
#   - wfview server on UDP 50001-50003: a wfview client on the laptop gets
#     the 7300's scope/waterfall, two-way audio and PTT over Tailscale/LAN.
#
# Why the GUI under xvfb and not the headless `wfserver`: nixpkgs only builds
# wfview.pro, and wfserver.pro doesn't compile rigctld.cpp at all, so it has
# no rigctld emulation to replace hamlib's rigctld with.
#
# Gotchas (wfview 2.23, from reading the source):
#   - Without [Program] hasRunSetup=true the GUI opens a modal first-run
#     dialog before touching the radio, which blocks forever headless.
#   - wfview writes [Server] GUID back into its config on load, so the
#     Nix-generated file is copied into StateDirectory on every start
#     rather than symlinked read-only from the store.
#   - Audio devices are matched by prefix of the PipeWire node description,
#     here the "IC-7300 RX"/"IC-7300 TX" virtual devices from ham-radio.nix.
#   - The server needs a user entry to accept a client at all. The
#     password is a throwaway on purpose (home network, single operator).
#
# WSJT-X uses the same virtual devices; wfview only carries audio for the
# remote (laptop) client.
# Don't run WSJT-X TX and remote SSB at the same time.
{ inputs, ... }:
{
  flake.modules.nixos.wfview =
    { pkgs, lib, config, ... }:
    let
      wfviewConf = pkgs.writeText "wfview.conf" (lib.generators.toINI { } {
        Program.hasRunSetup = true;

        Radio = {
          Manufacturer = 0; # Icom
          RigCIVuInt = 148; # 0x94, IC-7300 default CI-V address
          CIVisRadioModel = false;
          PTTType = 0; # CI-V
          SerialPortRadio = "/dev/ic7300";
          SerialPortBaud = 115200;
          AudioSystem = 0; # Qt audio (PipeWire via its pulse layer)
        };

        LAN = {
          EnableLAN = false; # radio is on USB, not the network
          EnableRigCtlD = true;
          RigCtlPort = 4532;
        };

        Server = {
          ServerEnabled = true;
          DisableUI = true; # less CI-V polling for a window nobody sees
          ServerControlPort = 50001;
          ServerCivPort = 50002;
          ServerAudioPort = 50003;
          ServerAudioInput = "IC-7300 RX"; # ham-radio.nix virtual devices
          ServerAudioOutput = "IC-7300 TX";
          "Users\\size" = 1;
          "Users\\1\\Username" = "jevin";
          "Users\\1\\Password" = "shop";
          "Users\\1\\UserType" = 0; # full access incl. TX
        };
      });
    in
    {
      environment.systemPackages = [ pkgs.wfview ];

      # Follows the radio's power switch, same as rigctld did: the 7300's USB
      # devices vanish when it's off, bindsTo stops wfview then, and wantedBy
      # the device unit starts it again when the radio comes back.
      systemd.services.wfview = {
        description = "wfview: IC-7300 network server + rigctld emulation on :4532";
        after = [ "dev-ic7300.device" ];
        bindsTo = [ "dev-ic7300.device" ];
        wantedBy = [ "dev-ic7300.device" ];

        # jevin's user PipeWire (linger is on, see ham-radio.nix) holds the
        # 7300's audio codec; point Qt at its socket.
        environment.XDG_RUNTIME_DIR = "/run/user/1000";

        serviceConfig = {
          User = "jevin";
          Group = "dialout";
          SupplementaryGroups = [ "audio" ];
          StateDirectory = "wfview";
          LogsDirectory = "wfview";
          ExecStartPre = "${pkgs.coreutils}/bin/install -m 0644 ${wfviewConf} /var/lib/wfview/wfview.conf";
          # Fixed display, one per headless app: wfview :97, wsjtx-wspr :98,
          # wlgate :99 (its wrapper hardcodes xvfb-run's default). With `-a`
          # wfview grabbed :99 first, wlgate's and the beacon's Xvfb then
          # failed to start and all three shared one 640x480 screen.
          ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -n 97 -s '-screen 0 1600x1000x24' ${pkgs.wfview}/bin/wfview -s /var/lib/wfview/wfview.conf -l /var/log/wfview/wfview.log";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      # wlgate reconnects to :4532 several times a second and wfview logs every
      # "session connected"/"disconnected", so the log grows by tens of MB a
      # day. wfview keeps the file open, hence copytruncate.
      services.logrotate.settings.wfview = {
        files = "/var/log/wfview/wfview.log";
        frequency = "daily";
        rotate = 3;
        compress = true;
        copytruncate = true;
        missingok = true;
        notifempty = true;
      };

      networking.firewall.allowedTCPPorts = [ 4532 ]; # rigctld emulation
      networking.firewall.allowedUDPPorts = [ 50001 50002 50003 ];
    };
}
