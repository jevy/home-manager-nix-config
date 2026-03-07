{ ... }:
{
  flake.modules.homeManager.bluetoothLock =
    { pkgs, ... }:
    let
      # MAC address of Garmin Vivoactive 5 — update after pairing
      garminMac = "CHANGE_ME";

      checkInterval = 10; # seconds between checks
      missThreshold = 3; # consecutive misses before locking

      script = pkgs.writeShellScript "bluetooth-lock" ''
        set -euo pipefail

        MAC="${garminMac}"
        INTERVAL=${toString checkInterval}
        MISS_THRESHOLD=${toString missThreshold}
        miss_count=0

        echo "Bluetooth lock: watching $MAC (lock after $MISS_THRESHOLD misses, checking every ''${INTERVAL}s)"

        while true; do
          if ${pkgs.bluez}/bin/hcitool name "$MAC" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q .; then
            if [ "$miss_count" -gt 0 ]; then
              echo "Device reachable again (was at $miss_count misses)"
            fi
            miss_count=0
          else
            miss_count=$((miss_count + 1))
            echo "Device not found (miss $miss_count/$MISS_THRESHOLD)"
            if [ "$miss_count" -ge "$MISS_THRESHOLD" ]; then
              echo "Threshold reached — locking session"
              ${pkgs.systemd}/bin/loginctl lock-session
              # Reset counter so we don't spam lock commands
              miss_count=0
              # Wait longer after locking to avoid repeated locks
              sleep 60
              continue
            fi
          fi
          sleep "$INTERVAL"
        done
      '';
    in
    {
      systemd.user.services.bluetooth-lock = {
        Unit = {
          Description = "Lock screen when Garmin Vivoactive 5 goes out of Bluetooth range";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = toString script;
          Restart = "on-failure";
          RestartSec = 30;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
