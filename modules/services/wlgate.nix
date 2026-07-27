# WaveLogGate: pushes CAT data (freq, mode, power) from rigctld to Wavelog,
# and receives WSJT-X N1MM ADIF broadcasts on :2333 for automatic QSO logging.
#
# Architecture notes (v2.0.8):
#   - QSO push is Go-side: net/http POST to <url>/api/qso. Since v2.0.8
#     (2026-07-06) failed POSTs land in a persistent buffer and are retried
#     once the network is back — the buffer survives a WavelogGate restart.
#     (Pre-2.0.8 a failed POST silently dropped the QSO; recovery meant
#     replaying from ~/.local/share/WSJT-X/wsjtx_log.adi.)
#   - The 06:00 daily restart below predates the 2.0.8 buffer (it papered
#     over stale keep-alive conns wedging POSTs). Kept as belt-and-braces
#     for one field-use cycle; removable if 2.0.8 logs clean POSTs.
#   - The -debug flag is the only knob for logging; without it the binary is
#     silent per-QSO. We enable it so journalctl -u wlgate shows POST activity.
#   - Runs headless under xvfb-run because Wails always opens a webview.
{ inputs, ... }:
{
  flake.modules.nixos.wlgate =
    { pkgs, lib, config, ... }:
    let
      waveloggate = pkgs.callPackage ../../pkgs/waveloggate.nix { };

      # sops-nix decrypts home-manager secrets here
      sopsSecretPath = "/home/jevin/.config/sops-nix/secrets/wavelog_api_key";

      # Generate config.json at service start, injecting the API key from sops
      wlgateWrapper = pkgs.writeShellScript "wlgate-start" ''
        CONFIG_DIR="$HOME/.config/WavelogGate"
        CONFIG_FILE="$CONFIG_DIR/config.json"
        mkdir -p "$CONFIG_DIR"

        # Read API key from sops secret
        if [ ! -f "${sopsSecretPath}" ]; then
          echo "ERROR: wavelog_api_key not found at ${sopsSecretPath}" >&2
          echo "Ensure sops-nix home-manager activation has run." >&2
          exit 1
        fi
        API_KEY=$(cat "${sopsSecretPath}")

        # Write config with API key injected
        cat > "$CONFIG_FILE" <<CONF
        {
          "version": 6,
          "profile": 0,
          "profileNames": ["IC-7300", "Profile 2"],
          "udp_enabled": true,
          "udp_port": 2333,
          "minimap_enabled": false,
          "udp_emit_enabled": true,
          "udp_emit_port": 2237,
          "udp_emit_host": "127.0.0.1",
          "profiles": [
            {
              "wavelog_url": "https://wavelog.jevy.org",
              "wavelog_key": "$API_KEY",
              "wavelog_id": "1",
              "wavelog_radioname": "IC-7300",
              "wavelog_pmode": true,
              "flrig_host": "127.0.0.1",
              "flrig_port": "12345",
              "flrig_ena": false,
              "hamlib_host": "127.0.0.1",
              "hamlib_port": "4532",
              "hamlib_ena": true,
              "ignore_pwr": false,
              "rotator_enabled": false,
              "rotator_host": "",
              "rotator_port": "4533",
              "rotator_threshold_az": 2,
              "rotator_threshold_el": 2,
              "rotator_park_az": 0,
              "rotator_park_el": 0,
              "hamlib_managed": false,
              "hamlib_model": 0,
              "hamlib_device": "",
              "hamlib_baud": 0,
              "hamlib_parity": "",
              "hamlib_stop_bits": 0,
              "hamlib_handshake": ""
            },
            {
              "wavelog_url": "",
              "wavelog_key": "",
              "wavelog_id": "0",
              "wavelog_radioname": "WLGate",
              "wavelog_pmode": true,
              "flrig_host": "127.0.0.1",
              "flrig_port": "12345",
              "flrig_ena": false,
              "hamlib_host": "127.0.0.1",
              "hamlib_port": "4532",
              "hamlib_ena": false,
              "ignore_pwr": false,
              "rotator_enabled": false,
              "rotator_host": "",
              "rotator_port": "4533",
              "rotator_threshold_az": 2,
              "rotator_threshold_el": 2,
              "rotator_park_az": 0,
              "rotator_park_el": 0,
              "hamlib_managed": false,
              "hamlib_model": 0,
              "hamlib_device": "",
              "hamlib_baud": 0,
              "hamlib_parity": "",
              "hamlib_stop_bits": 0,
              "hamlib_handshake": ""
            }
          ]
        }
        CONF

        exec ${waveloggate}/bin/wavelog-gate-headless -debug
      '';
    in
    {
      environment.systemPackages = [ waveloggate ];

      systemd.services.wlgate = {
        description = "WaveLogGate — rigctld to Wavelog bridge";
        after = [ "network-online.target" "rigctld.service" ];
        wants = [ "network-online.target" ];
        requires = [ "rigctld.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          ExecStart = wlgateWrapper;
          Restart = "on-failure";
          RestartSec = 10;
          User = "jevin";
          Group = "users";
        };
      };

      # POSTs to Wavelog silently stop after multi-day uptime (likely stale
      # HTTP keep-alive — wlgate's http.Transport has no IdleConnTimeout).
      # Daily restart at 06:00 local keeps the client fresh.
      systemd.timers.wlgate-restart = {
        description = "Daily restart of WaveLogGate";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 06:00:00";
          Persistent = true;
          Unit = "wlgate-restart.service";
        };
      };

      systemd.services.wlgate-restart = {
        description = "Restart WaveLogGate";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "/run/current-system/sw/bin/systemctl restart wlgate.service";
        };
      };

      # WaveLogGate listens on these ports:
      # 2333/udp  — WSJT-X QSO data
      # 54321/tcp — QSY requests from Wavelog
      # 54322/tcp — WebSocket live radio status
      networking.firewall.allowedTCPPorts = [ 54321 54322 ];
      networking.firewall.allowedUDPPorts = [ 2333 ];
    };
}
