# Ham radio VNC desktop — xfce4 session with WSJT-X, GridTracker, etc.
# Accessible via VNC on :5942
#
# UDP routing:
#   WSJT-X primary UDP (:2237) → GridTracker (binary decode stream)
#   WSJT-X N1MM broadcast (:2333) → WavelogGate (QSO log packets)
{ inputs, ... }:
{
  flake.modules.nixos.wsjtx =
    { pkgs, lib, config, ... }:
    let
      # WSJT-X stores config as Qt QSettings INI at ~/.config/WSJT-X.ini
      # (NOT ~/.config/WSJT-X/WSJT-X.ini — that path is never read)
      # Key names sourced from Configuration.cpp and mainwindow.cpp
      wsjtxConfig = pkgs.writeText "WSJT-X.ini" ''
        [Configuration]
        MyCall=VA3JEV
        MyGrid=FN25EK
        Rig=Hamlib NET rigctl
        CATNetworkPort=localhost
        SoundInName="sysdefault:CARD=IC7300"
        SoundOutName="sysdefault:CARD=IC7300"
        AudioInputChannel=Mono
        AudioOutputChannel=Mono
        UDPServer=127.0.0.1
        UDPServerPort=2237
        AcceptUDPRequests=true
        PSKReporter=true
        PSKReporterTCPIP=false
        After73=false
        MonitorOFF=false
        PromptToLog=false
        N1MMServer=localhost
        N1MMServerPort=2333
        BroadcastToN1MM=true
        TxWatchdog=6
        TwoPass=true
        SingleDecode=false

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
        exec = "${pkgs.grig}/bin/grig -m 2 -r localhost:4532";
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
        # Seed WSJT-X config on first run; runtime edits via VNC persist
        # WSJT-X reads QSettings from ~/.config/WSJT-X.ini (not a subdirectory)
        if [ ! -f "$HOME/.config/WSJT-X.ini" ]; then
          cp ${wsjtxConfig} "$HOME/.config/WSJT-X.ini"
          chmod 644 "$HOME/.config/WSJT-X.ini"
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
