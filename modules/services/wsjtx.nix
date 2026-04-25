# Ham radio VNC desktop — xfce4 session with WSJT-X, GridTracker, etc.
# Accessible via VNC on :5942
# UDP decodes sent to WLGate (:2333), which logs to Wavelog and relays to GridTracker (:2237)
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
        MyGrid=FN25EK
        Rig=Hamlib NET rigctl
        CATNetworkPort=localhost:4532
        PTTMethod=1
        SplitMode=2
        DataMode=2
        Polling=3
        SoundInName=plughw:CARD=IC7300,DEV=0
        SoundOutName=plughw:CARD=IC7300,DEV=0
        AudioInputChannel=Mono
        AudioOutputChannel=Mono
        UDPEnable=true
        UDPServer=127.0.0.1
        UDPServerPort=2333
        AcceptUDPRequests=true
        PSKReporter=true
        PSKReporterTCPIP=false
        After73=false
        MonitorOFF=false
        AutoLog=true
        PromptToLog=false
        Region=2
        TxWatchdog=6
        TwoPass=true
        SingleDecode=false
        DecodedTextFont="Monospace, 9"

        [Common]
        Mode=FT8
        ModeTx=FT8
        DialFreq=14074000
        TxFreq=1500
        RxFreq=729
        NDepth=3
        NoOwnCall=false
        SaveDecoded=true
        SaveAll=false
        SaveNone=false
        AutoSeq=true

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

      # grig doesn't ship a .desktop file — create one
      grigDesktop = pkgs.makeDesktopItem {
        name = "grig";
        desktopName = "Grig";
        comment = "Hamlib rig control GUI";
        exec = "${pkgs.grig}/bin/grig";
        categories = [ "HamRadio" ];
      };

      hamPackages = with pkgs; [
        dbus
        wsjtx
        gridtracker
        grig
        grigDesktop
        flrig
      ];

      allPackages = xfcePackages ++ hamPackages;

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
        export PATH="${lib.makeBinPath allPackages}:$PATH"
        export XDG_DATA_DIRS="${lib.concatMapStringsSep ":" (p: "${p}/share") allPackages}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
        export XDG_CONFIG_DIRS="${lib.concatMapStringsSep ":" (p: "${p}/etc/xdg") allPackages}:''${XDG_CONFIG_DIRS:-/etc/xdg}"

        ${pkgs.tigervnc}/bin/Xvnc :42 -geometry 2880x1800 -depth 24 -SecurityTypes None -localhost 0 &
        sleep 1

        exec ${pkgs.xfce4-session}/bin/xfce4-session
      '';
    in
    {
      environment.systemPackages = allPackages;

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
