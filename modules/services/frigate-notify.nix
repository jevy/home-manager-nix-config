# Frigate camera event desktop notifications via Home Assistant WebSocket API
{ ... }:
{
  flake.modules.homeManager.frigateNotify =
    { config, pkgs, lib, ... }:
    let
      ha_url = "https://homeassistant.jevy.org";

      pythonEnv = pkgs.python3.withPackages (ps: [
        ps.websockets
        ps.aiohttp
      ]);

      frigateNotifyScript = pkgs.writeTextFile {
        name = "frigate-notify";
        executable = true;
        text = ''
          #!${pythonEnv}/bin/python3
          import asyncio
          import json
          import os
          import subprocess
          import tempfile
          import time
          import ssl

          import websockets
          import aiohttp

          HA_URL = os.environ["HA_URL"]
          TOKEN_FILE = os.environ["HA_TOKEN_FILE"]

          # Rate limit: min seconds between notifications per camera
          RATE_LIMIT_SECS = 30
          # Delay before fetching thumbnail (lets Frigate generate it)
          THUMBNAIL_DELAY = 1.5

          seen_events = set()
          last_notify_per_camera = {}


          def read_token():
              with open(TOKEN_FILE) as f:
                  return f.read().strip()


          def send_notification(summary, body, icon_path=None):
              cmd = ["notify-send", "-a", "frigate"]
              if icon_path:
                  cmd += ["-i", icon_path]
              cmd += [summary, body]
              subprocess.run(cmd)


          async def fetch_thumbnail(http, event_id, token):
              url = f"{HA_URL}/api/frigate/notifications/{event_id}/thumbnail.jpg"
              headers = {"Authorization": f"Bearer {token}"}
              try:
                  async with http.get(url, headers=headers, ssl=False) as resp:
                      if resp.status == 200:
                          data = await resp.read()
                          tmp = tempfile.NamedTemporaryFile(
                              suffix=".jpg", prefix="frigate-", delete=False
                          )
                          tmp.write(data)
                          tmp.close()
                          return tmp.name
              except Exception as e:
                  print(f"Thumbnail fetch failed: {e}", flush=True)
              return None


          async def handle_message(msg, token, http):
              if msg.get("type") != "event":
                  return

              trigger = msg.get("event", {}).get("variables", {}).get("trigger", {})
              payload = trigger.get("payload_json") or trigger.get("payload")

              if not payload:
                  return

              # payload might be a string if payload_json isn't available
              if isinstance(payload, str):
                  try:
                      payload = json.loads(payload)
                  except json.JSONDecodeError:
                      return

              event_type = payload.get("type")
              after = payload.get("after", {})
              event_id = after.get("id")
              camera = after.get("camera", "unknown")
              label = after.get("label", "object")
              severity = after.get("max_severity")
              score = after.get("top_score", after.get("score", 0))

              # Only notify on alert-severity events
              if severity != "alert":
                  return

              if not event_id:
                  return

              # Skip if already notified (handles new + update for same event)
              if event_id in seen_events:
                  return

              seen_events.add(event_id)
              if len(seen_events) > 500:
                  seen_events.clear()

              # Rate limit per camera
              now = time.time()
              last = last_notify_per_camera.get(camera, 0)
              if now - last < RATE_LIMIT_SECS:
                  return
              last_notify_per_camera[camera] = now

              # Wait for thumbnail to be generated
              await asyncio.sleep(THUMBNAIL_DELAY)

              icon_path = await fetch_thumbnail(http, event_id, token)

              camera_name = camera.replace("_", " ").title()
              summary = f"{label.title()} Detected"
              if isinstance(score, (int, float)) and score > 0:
                  body = f"{camera_name} ({score:.0%})"
              else:
                  body = camera_name

              send_notification(summary, body, icon_path)
              print(f"Notified: {label} on {camera} (event {event_id})", flush=True)


          async def listen():
              token = read_token()
              ws_url = (
                  HA_URL.replace("https://", "wss://").replace("http://", "ws://")
                  + "/api/websocket"
              )

              ssl_ctx = ssl.create_default_context()
              ssl_ctx.check_hostname = False
              ssl_ctx.verify_mode = ssl.CERT_NONE

              async with websockets.connect(
                  ws_url, ssl=ssl_ctx, ping_interval=20, ping_timeout=10
              ) as ws:
                  # Auth handshake
                  msg = json.loads(await ws.recv())
                  if msg["type"] != "auth_required":
                      raise Exception(f"Unexpected message: {msg}")

                  await ws.send(json.dumps({"type": "auth", "access_token": token}))
                  msg = json.loads(await ws.recv())
                  if msg["type"] != "auth_ok":
                      raise Exception(f"Auth failed: {msg}")

                  print("Connected to Home Assistant", flush=True)

                  # Subscribe to frigate events via MQTT trigger
                  await ws.send(
                      json.dumps(
                          {
                              "id": 1,
                              "type": "subscribe_trigger",
                              "trigger": {
                                  "platform": "mqtt",
                                  "topic": "frigate/events",
                              },
                          }
                      )
                  )

                  # Consume subscription confirmation
                  confirm = json.loads(await ws.recv())
                  if not confirm.get("success", True):
                      raise Exception(f"Subscription failed: {confirm}")

                  print("Subscribed to frigate/events", flush=True)

                  # Process events
                  async with aiohttp.ClientSession() as http:
                      async for raw in ws:
                          try:
                              msg = json.loads(raw)
                              await handle_message(msg, token, http)
                          except Exception as e:
                              print(f"Error handling message: {e}", flush=True)


          async def main():
              while True:
                  try:
                      await listen()
                  except Exception as e:
                      print(f"Connection lost: {e}. Reconnecting in 15s...", flush=True)
                      await asyncio.sleep(15)


          if __name__ == "__main__":
              asyncio.run(main())
        '';
      };
    in
    {
      systemd.user.services.frigate-notify = {
        Unit = {
          Description = "Frigate camera event desktop notifications";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${frigateNotifyScript}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = [
            "HA_TOKEN_FILE=${config.sops.secrets.homeassistant_token.path}"
            "HA_URL=${ha_url}"
            "PATH=${lib.makeBinPath [ pkgs.libnotify ]}"
          ];
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
