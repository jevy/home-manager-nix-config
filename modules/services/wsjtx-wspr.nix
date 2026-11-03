# WSPR beacon: WSJT-X on the IC-7300, 1 W, ~20% of 2-minute slots on TX,
# decoding and uploading spots to wsprnet the rest of the time, band hopping
# on the schedule below. Runs headless (xvfb) as jevin with its own settings
# file (`--rig-name=WSPR` → ~/.config/WSJT-X - WSPR.ini), so the interactive
# FT8 WSJT-X config in ~/.config/WSJT-X.ini is untouched.
#
#   IC-7300 ─ wfview :4532 (CAT + PTT) ─ WSJT-X ─ ic7300-rx/-tx (PipeWire audio)
#
# Starts whenever wfview does (i.e. when the radio is switched on) and stops
# with it. To use the radio for anything else (SSB through wfview, FT8 in the
# interactive WSJT-X), stop it first: `ssh shop-sdr sudo systemctl stop
# wsjtx-wspr` (the laptop's ic7300 / ic7300-ssb aliases do this). It comes
# back on the next radio power-cycle, or `sudo systemctl start wsjtx-wspr`.
#
# Why the patch: WSJT-X only transmits WSPR while "Enable Tx" is on, and that
# button isn't saved in settings, so every restart (radio power-cycle, deploy)
# would leave the beacon receive-only until someone clicked it. The patch
# turns it on 30 s after startup when WSJTX_WSPR_AUTO_TX is set and the mode
# is WSPR; without the variable WSJT-X behaves as stock.
#
# Station performance notes live in Obsidian (Second Brain vault), not here:
#   "Amateur Radio" (hub) → "RFI LLM Analysis from WSPR" (May 2026 baseline:
#   per-band TX/RX, reciprocity, antenna pattern) and "2026-10-31 - WSPR
#   Signal Collapse" (night-time RX drop, timeline, wspr.live queries).
#
# Audio goes through the ic7300-rx/-tx PipeWire devices, shared with wfview/JS8Call
# (see "IC-7300 audio" in ham-radio.nix). Sharing audio isn't sharing
# the transmitter though: still stop the beacon before SSB/FT8/JS8.
{ inputs, ... }:
{
  flake.modules.nixos.wsjtxWspr =
    { pkgs, lib, config, ... }:
    let
      wsjtxAutoTx = pkgs.wsjtx.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace widgets/mainwindow.cpp --replace-fail \
            '  splashTimer.start (20 * 1000);' \
            '  splashTimer.start (20 * 1000);
            if (qEnvironmentVariableIsSet ("WSJTX_WSPR_AUTO_TX"))
              QTimer::singleShot (30 * 1000, [=] {
                if (m_mode.startsWith ("WSPR") && !m_auto) auto_tx_mode (true);
              });'
        '';
      });

      # Enum-typed settings are QVariants WSJT-X writes itself; these strings
      # are copied verbatim from a working ~/.config/WSJT-X.ini.
      #
      # Band hopping: one QBitArray per phase (sunrise grayline, day, sunset
      # grayline, night, tune, rx-only), 32 bits, bit n = row n of WSJT-X's
      # band table (models/Bands.cpp: 160m=3, 80m=4, 60m=5, 40m=6, 30m=7,
      # 20m=8, 17m=9, 15m=10, 12m=11, 10m=12), LSB-first in each byte.
      # This is the schedule from the old 2026 beacon, chosen for the EFHW:
      #   sunrise 80/40/20 · day 40/20/10 · sunset 80/40/20 · night 80/40
      wsprIni = pkgs.writeText "WSJT-X - WSPR.ini" ''
        [Common]
        Mode=WSPR
        DialFreq=14095600
        WSPRfreq=1500
        TRPeriod=120
        PctTx=20
        dBm=30
        UploadSpots=true
        BandHopping=true
        WSPRPreferType1=true
        NDepth=3
        OutAttenuation=183
        SaveNone=true

        [Configuration]
        MyCall=VA3JEV
        MyGrid=FN25EK
        Rig=Hamlib NET rigctl
        CATNetworkPort=localhost:4532
        PTTMethod=@Variant(\0\0\0\x7f\0\0\0\x1eTransceiverFactory::PTTMethod\0\0\0\0\xfPTT_method_CAT\0)
        DataMode=@Variant(\0\0\0\x7f\0\0\0\x18\x43onfiguration::DataMode\0\0\0\0\xf\x64\x61ta_mode_data\0)
        SplitMode=@Variant(\0\0\0\x7f\0\0\0\x1eTransceiverFactory::SplitMode\0\0\0\0\x10split_mode_none\0)
        Region=@Variant(\0\0\0\x7f\0\0\0\x14IARURegions::Region\0\0\0\0\x4\x41LL\0)
        Polling=1
        SoundInName=ic7300-rx
        SoundOutName=ic7300-tx
        AudioInputChannel=Mono
        AudioOutputChannel=Mono
        PSKReporter=false
        UDPServer=127.0.0.1
        UDPServerPort=2237
        AcceptUDPRequests=false
        TxWatchdog=0

        [WSPR%20Band%20Hopping]
        GrayLineDuration=60
        phases\1\bands=@Variant(\0\0\0\r\0\0\0 P\x1\0\0)
        phases\2\bands=@Variant(\0\0\0\r\0\0\0 @\x11\0\0)
        phases\3\bands=@Variant(\0\0\0\r\0\0\0 P\x1\0\0)
        phases\4\bands=@Variant(\0\0\0\r\0\0\0 P\0\0\0)
        phases\5\bands=@Variant(\0\0\0\r\0\0\0 \0\0\0\0)
        phases\6\bands=@Variant(\0\0\0\r\0\0\0 \0\0\0\0)
        phases\size=6

        [MultiSettings]
        CurrentName=Default
        Splash_v1.7=false
      '';

      # Seed the settings fresh every start (WSJT-X rewrites the file while
      # running), then put the rig in a known beacon state before WSJT-X
      # attaches. SSB through wfview may have left it at 100 W, and WSJT-X
      # never sets power itself (3/255 ≈ 1.2 W). It also adopts whatever dial
      # frequency the rig is on: first test start came up on 14.178 (left over
      # from SSB) and, with 20m already the scheduled band, wouldn't have
      # hopped off it — WSPR in the phone segment. So tune to 20m WSPR, USB-D.
      # wfview's rigctld port can take a few seconds to come up after it
      # starts, hence the retry.
      prestart = pkgs.writeShellScript "wsjtx-wspr-prestart" ''
        install -m 0644 ${wsprIni} "$HOME/.config/WSJT-X - WSPR.ini"
        rig() { ${pkgs.hamlib_4}/bin/rigctl -m 2 -r 127.0.0.1:4532 "$@"; }
        for _ in $(seq 30); do
          if rig L RFPOWER 0.0118 && rig F 14095600 && rig M PKTUSB 0; then
            exit 0
          fi
          sleep 2
        done
        echo "could not set power/frequency via wfview :4532; refusing to start the beacon" >&2
        exit 1
      '';
    in
    {
      systemd.services.wsjtx-wspr = {
        description = "WSJT-X WSPR beacon (IC-7300 via wfview, band hopping, 1 W)";
        after = [ "wfview.service" "network-online.target" ];
        wants = [ "network-online.target" ];
        bindsTo = [ "wfview.service" ];
        wantedBy = [ "wfview.service" ];

        environment = {
          WSJTX_WSPR_AUTO_TX = "1";
          XDG_RUNTIME_DIR = "/run/user/1000";
        };
        path = [ pkgs.coreutils ];

        serviceConfig = {
          User = "jevin";
          Group = "users";
          SupplementaryGroups = [ "audio" ];
          ExecStartPre = prestart;
          # Release PTT whenever the beacon stops. Stopping it mid-TX
          # (2026-11-01 10:34) killed WSJT-X before it unkeyed and wfview left
          # the 7300 keyed for ~2 min, even across a band hop. `-` so a radio
          # that's already off doesn't fail the stop.
          ExecStopPost = "-${pkgs.hamlib_4}/bin/rigctl -m 2 -r 127.0.0.1:4532 T 0";
          # Fixed display :98 (see wfview.nix for the display map) so the
          # window can be screenshotted for debugging:
          #   ssh shop-sdr 'xwd -root -display :98 | magick xwd:- /tmp/wspr.png'
          ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -n 98 -s '-screen 0 1600x1000x24' ${wsjtxAutoTx}/bin/wsjtx --rig-name=WSPR";
          Restart = "on-failure";
          RestartSec = 30;
        };
      };
    };
}
