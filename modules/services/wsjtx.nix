# Ham radio VNC desktop — xfce4 session with WSJT-X, GridTracker, etc.
# Accessible via VNC on :5942
# UDP decodes forwarded to WLGate (:2333) for Wavelog logging
{ inputs, ... }:
{
  flake.modules.nixos.wsjtx =
    { pkgs, lib, config, ... }:
    let
      # WSJT-X stores config as Qt QSettings INI
      # Key names sourced from Configuration.cpp and mainwindow.cpp
      wsjtxConfig = pkgs.writeText "WSJT-X.ini" ''
        [Configuration]
        MyCall=VA3JEV
        MyGrid=FN25ek
        Rig=Hamlib NET rigctl
        CATNetworkPort=localhost:4532
        PTTMethod=1
        SplitMode=2
        DataMode=2
        Polling=3
        SoundInName=sysdefault:CARD=IC7300
        SoundOutName=sysdefault:CARD=IC7300
        AudioInputChannel=Mono
        AudioOutputChannel=Mono
        UDPEnable=true
        UDPServer=127.0.0.1
        UDPServerPort=2333
        AcceptUDPRequests=false
        PSKReporter=true
        PSKReporterTCPIP=false
        After73=false
        MonitorOFF=false
        AutoLog=true
        PromptToLog=false
        Region=2
        TxWatchdog=0
        TwoPass=true
        SingleDecode=false
        DecodedTextFont="Monospace, 9"

        [Common]
        Mode=WSPR
        ModeTx=WSPR
        DialFreq=14095600
        TxFreq=1500
        RxFreq=1500
        WSPRfreq=1500
        TRPeriod=120
        PctTx=20
        dBm=30
        UploadSpots=true
        BandHopping=true
        WSPRPreferType1=true
        NoOwnCall=false
        NDepth=3
        SaveDecoded=true
        SaveAll=false
        SaveNone=false

        [Tune]
        Audio/OutputBufferMs=0
        Audio/InputBufferFrames=4800
      '';

      xfcePackages = with pkgs; [
        xfce4-session
        xfwm4
        xfce4-panel
        xfce4-terminal
        xfce4-settings
        xfconf
        thunar
      ];

      hamDesktopWrapper = pkgs.writeShellScript "ham-desktop" ''
        CONFIG_DIR="$HOME/.config/WSJT-X"
        mkdir -p "$CONFIG_DIR"

        # Seed WSJT-X config on first run; runtime edits via VNC persist
        if [ ! -f "$CONFIG_DIR/WSJT-X.ini" ]; then
          cp ${wsjtxConfig} "$CONFIG_DIR/WSJT-X.ini"
          chmod 644 "$CONFIG_DIR/WSJT-X.ini"
        fi

        # Autostart WSJT-X inside xfce
        mkdir -p "$HOME/.config/autostart"
        cat > "$HOME/.config/autostart/wsjtx.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=WSJT-X
Exec=wsjtx
DESKTOP

        export DISPLAY=:42
        export QT_SCALE_FACTOR=2
        export PATH="${lib.makeBinPath xfcePackages}:${pkgs.dbus}/bin:${pkgs.wsjtx}/bin:${pkgs.gridtracker}/bin:${pkgs.wfview}/bin:$PATH"
        export XDG_DATA_DIRS="${lib.concatMapStringsSep ":" (p: "${p}/share") xfcePackages}:${pkgs.wsjtx}/share:${pkgs.gridtracker}/share:${pkgs.wfview}/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
        export XDG_CONFIG_DIRS="${lib.concatMapStringsSep ":" (p: "${p}/etc/xdg") xfcePackages}:''${XDG_CONFIG_DIRS:-/etc/xdg}"

        ${pkgs.tigervnc}/bin/Xvnc :42 -geometry 2880x1800 -depth 24 -SecurityTypes None -localhost 0 &
        sleep 1

        exec ${pkgs.xfce4-session}/bin/xfce4-session
      '';
    in
    {
      environment.systemPackages = xfcePackages ++ [
        pkgs.wsjtx
        pkgs.gridtracker
      ];

      systemd.services.wsjtx-wspr = {
        description = "Ham radio VNC desktop (xfce4)";
        after = [ "network-online.target" "rigctld.service" "pipewire.service" ];
        wants = [ "network-online.target" ];
        requires = [ "rigctld.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ExecStart = hamDesktopWrapper;
          Restart = "on-failure";
          RestartSec = 30;
          User = "jevin";
          Group = "users";
          SupplementaryGroups = [ "dialout" "audio" ];
        };
      };

      # Allow VNC access over Tailscale (Xvnc :42 = port 5942)
      networking.firewall.allowedTCPPorts = [ 5942 ];
    };
}
