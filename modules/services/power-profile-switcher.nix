# Automatic power profile switching based on AC/battery state.
#
# - Plugged in:        performance
# - Battery > 20%:     balanced
# - Battery ≤ 20%:     power-saver
#
# Triggered by udev on AC plug/unplug + systemd timer every 2 min for battery level.
{ ... }:
{
  flake.modules.nixos.powerProfileSwitcher =
    { pkgs, ... }:
    let
      script = pkgs.writeShellScript "power-profile-switcher" ''
        set -euo pipefail

        # Detect AC status (check all Mains-type power supplies)
        ac_online=0
        for supply in /sys/class/power_supply/*/; do
          if [ "$(cat "$supply/type" 2>/dev/null)" = "Mains" ] &&
             [ "$(cat "$supply/online" 2>/dev/null)" = "1" ]; then
            ac_online=1
            break
          fi
        done

        # Detect lowest battery level across all batteries
        battery_level=100
        for supply in /sys/class/power_supply/*/; do
          if [ "$(cat "$supply/type" 2>/dev/null)" = "Battery" ]; then
            level=$(cat "$supply/capacity" 2>/dev/null || echo "100")
            if [ "$level" -lt "$battery_level" ]; then
              battery_level=$level
            fi
          fi
        done

        if [ "$ac_online" = "1" ]; then
          target="performance"
        elif [ "$battery_level" -le 20 ]; then
          target="power-saver"
        else
          target="balanced"
        fi

        current=$(${pkgs.power-profiles-daemon}/bin/powerprofilesctl get 2>/dev/null || echo "unknown")

        if [ "$current" != "$target" ]; then
          echo "Switching profile: $current → $target (AC=$ac_online, battery=$battery_level%)"
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$target"
        fi
      '';
    in
    {
      # Systemd service that runs the switcher script
      systemd.services.power-profile-switcher = {
        description = "Automatic power profile switching";
        after = [ "power-profiles-daemon.service" ];
        wants = [ "power-profiles-daemon.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = script;
        };
      };

      # Timer: check battery level every 2 minutes
      systemd.timers.power-profile-switcher = {
        description = "Poll battery level for power profile switching";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "2min";
        };
      };

      # Udev rule: trigger immediately on AC plug/unplug
      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${pkgs.systemd}/bin/systemctl start power-profile-switcher.service"
      '';
    };
}
