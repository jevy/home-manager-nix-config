# xrdp on :3389 → fresh XFCE session per RDP login. Auth is the user's
# Linux password (PAM). Sesman keeps sessions alive across disconnect:
# close the RDP window → reconnect → same session, same apps still
# running. Use this to drive SDR GUIs (sparksdr, CubicSDR, sdrpp,
# sdrangel) interactively from a Linux/Mac/Windows RDP client.
#
# One-time on the host: `sudo passwd jevin` to set a Linux password
# (separate from your SSH key — RDP needs PAM auth).
{ ... }:
{
  flake.modules.nixos.remoteDesktop =
    { pkgs, ... }:
    {
      services.xrdp = {
        enable = true;
        defaultWindowManager = "${pkgs.xfce.xfce4-session}/bin/xfce4-session";
        openFirewall = true;

        # Default Xorg backend (xorgxrdp driver) has no GLX → Avalonia/
        # SkiaSharp apps (SparkSDR) hang at splash trying to init GPU
        # rendering. Switch to Xvnc, which exposes llvmpipe GLX so
        # GL-using apps render via software.
        extraConfDirCommands = ''
          sed -i \
            -e 's/^\[Xorg\]$/[Xvnc]/' \
            -e 's/^name=Xorg$/name=Xvnc/' \
            -e 's/^lib=libxup.so$/lib=libvnc.so/' \
            -e 's/^code=20$/ip=127.0.0.1\nchansrvport=DISPLAY(14)\ndelay_ms=2000/' \
            $out/xrdp.ini

          # Replace sesman.ini [Xorg] block with [Xvnc] — sesman looks up
          # the section matching xrdp.ini's session-type name, so without
          # an [Xvnc] section it errors "X server could not be started".
          # -SecurityTypes None: xrdp speaks VNC to Xvnc on localhost; without
          # this TigerVNC demands a ~/.vnc/passwd and Xvnc exits before xrdp
          # can connect → same "X server could not be started" symptom.
          sed -i '/^\[Xorg\]$/,/^\[/ { /^\[Xorg\]$/d; /^param=/d; }' $out/sesman.ini
          # NOTE: do NOT pass `-nolisten tcp` — xrdp talks to Xvnc over its
          # VNC TCP port on 127.0.0.1, so Xvnc must listen on TCP. The
          # `-localhost` flag restricts that to loopback only.
          printf '\n[Xvnc]\nparam=%s/bin/Xvnc\nparam=-bs\nparam=-localhost\nparam=-dpi\nparam=96\nparam=-SecurityTypes\nparam=None\n' "${pkgs.tigervnc}" >> $out/sesman.ini

          # Default LogFile=/dev/null silently swallows every sesman error
          # (including X-server-start failures). Mirror to syslog so
          # `journalctl -u xrdp-sesman` shows what broke. (sesman refuses
          # /dev/stderr — it insists on a real writable file.)
          sed -i \
            -e 's|^LogFile=.*|LogFile=/var/log/xrdp-sesman.log|' \
            -e 's|^LogLevel=.*|LogLevel=DEBUG|' \
            -e 's|^EnableSyslog=.*|EnableSyslog=true|' \
            $out/sesman.ini
        '';
      };

      # Pieces the spawned RDP session needs:
      #   - xfce4-* / xfwm4 / xfce4-panel: launched by xfce4-session
      #   - tigervnc: provides Xvnc, which xrdp's libvnc.so spawns
      environment.systemPackages = with pkgs; [
        xfce.xfce4-session
        xfce.xfwm4
        xfce.xfce4-panel
        xfce.xfce4-settings
        xfce.xfconf
        xfce.thunar
        xfce.xfce4-terminal
        xfce.xfce4-whiskermenu-plugin
        xfce.garcon
        tigervnc
        xterm
      ];
    };
}
