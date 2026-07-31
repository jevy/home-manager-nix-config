# Always-mono microphone on macOS (mac-work host).
#
# The Scarlett Solo presents two USB capture channels: ch1 = XLR mic, ch2 =
# instrument. Apps that record the device in stereo therefore get the mic on
# the left only. Newer Scarletts fix this in hardware ("Combine Inputs" — hold
# Direct for 3s on a 4th Gen), but this machine's unit is a *2nd Gen*
# (USB 1235:8205, product string "Scarlett Solo USB"), and 2nd Gen Scarletts
# expose no software-controllable state at all — no Focusrite Control, no
# firmware mixer. macOS has no native fix either: Audio MIDI Setup's aggregate
# devices combine *devices* and reorder channels, they cannot duplicate one
# input channel across two, and Accessibility's "play stereo audio as mono" is
# output-only.
#
# So the fix is done in software, in two halves:
#
#   1. BlackHole 2ch — a virtual audio device (a CoreAudio HAL plug-in). This
#      is the thing apps will select as their microphone. Installed by the
#      nix-darwin half below, because HAL plug-ins must live in
#      /Library/Audio/Plug-Ins/HAL, which is root-owned.
#
#   2. mono-mic — a small launchd-supervised bridge that reads the Scarlett's
#      channel 1 and writes it to *both* channels of BlackHole. BlackHole is
#      only a pipe; on its own it duplicates nothing. This is the home-manager
#      half.
#
# After a rebuild, pick "BlackHole 2ch" as the input device (system-wide in
# Sound settings, or per-app) and the mic is centred everywhere.
#
# Trade-off worth knowing: apps now capture BlackHole rather than the Scarlett,
# so if the bridge dies the mic goes silent. launchd keeps it alive and the
# script reconnects on its own when the interface is unplugged and returns, but
# it is a moving part that a hardware "Combine Inputs" switch would not be.
#
# Clock drift: BlackHole has no crystal — it derives its timeline from
# mach_absolute_time() (BlackHole.c, gDevice_AnchorHostTime), so the two ends of
# the bridge are the Scarlett's oscillator and the Mac's. Measured 2026-07-31
# over 415 s / 77.8k callbacks, against both time.monotonic() and CoreAudio's
# AudioTimeStamp.mHostTime (which agree): the Scarlett runs **+5.54 ppm fast**,
# i.e. it delivers ~957 more frames per hour than BlackHole consumes. That
# surplus accumulates in PortAudio's cross-device ring buffer until it resyncs,
# costing roughly one dropped block (~5 ms) per hour. Nothing is published
# about this — Focusrite specs jitter and THD, not crystal accuracy — so the
# number is empirical, and it will wander a few ppm as the interface warms up.
#
# If that click ever becomes annoying, the fix is an Aggregate Device (Scarlett
# + BlackHole) with drift correction enabled, pointing the bridge at that single
# device so CoreAudio resamples instead. Not done here because aggregate devices
# live in the audio prefs plist and cannot be declared from Nix.
{ ... }:
let
  # Device names are matched case-insensitively as substrings, so they survive
  # macOS's habit of appending disambiguating suffixes when two of a kind are
  # attached.
  inputDevice = "Scarlett Solo USB";
  outputDevice = "BlackHole 2ch";

  # 0-indexed: channel 0 is the Solo's input 1, the XLR mic — the "left" one
  # everything currently records into.
  sourceChannel = 0;
in
{
  # ── Half 1: the virtual device ────────────────────────────────────────────
  flake.modules.darwin.monoMic =
    { pkgs, ... }:
    let
      # nixpkgs' blackhole defaults to a 256-channel build; 2ch is what we want
      # for a microphone, and it keeps the device out of the way in app pickers
      # that enumerate every channel.
      blackhole = pkgs.blackhole.override { channel = "2ch"; };
      driver = "${blackhole}/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver";
    in
    {
      # The bundle is *copied* rather than symlinked into place: coreaudiod
      # loads HAL plug-ins as root very early, and a driver that depends on
      # /nix being present and readable at that moment is a boot-order risk for
      # no benefit. The stamp file records which store path the copy came from,
      # so activation is idempotent and coreaudiod is only restarted (which
      # briefly interrupts all audio) when the driver actually changes.
      system.activationScripts.postActivation.text = ''
        echo "setting up BlackHole 2ch (mono-mic)..." >&2
        halDir=/Library/Audio/Plug-Ins/HAL
        target="$halDir/BlackHole2ch.driver"
        stamp="$halDir/.BlackHole2ch.nix-source"

        if [ ! -e "$target" ] || [ "$(cat "$stamp" 2>/dev/null)" != "${driver}" ]; then
          mkdir -p "$halDir"
          rm -rf "$target"
          cp -R "${driver}" "$target"
          # The store copy is read-only; coreaudiod does not need to write to
          # the bundle, but leaving it 0444 makes a later `rm -rf` noisy.
          chmod -R u+w "$target"
          chown -R root:wheel "$target"
          echo "${driver}" > "$stamp"
          killall coreaudiod 2>/dev/null || true
          echo "  installed, coreaudiod restarted" >&2
        fi
      '';
    };

  # ── Half 2: the mono bridge ───────────────────────────────────────────────
  flake.modules.homeManager.monoMic =
    { config, pkgs, ... }:
    let
      # Kept inline rather than in pkgs/ because it is service glue, not a
      # reusable package — it only makes sense next to the launchd agent that
      # supervises it.
      mono-mic = pkgs.writers.writePython3Bin "mono-mic"
        {
          libraries = with pkgs.python3Packages; [
            sounddevice
            numpy
          ];
          # The script is formatted for readability over flake8's taste.
          flakeIgnore = [ "E501" ];
        }
        ''
          """Bridge one input channel of a capture device onto both channels of
          a virtual output device, so a mono source is centred for every app
          that opens the virtual device.

          Runs forever: if either device is missing (interface unplugged, or
          coreaudiod restarted out from under us) it waits and retries rather
          than exiting, so launchd's KeepAlive stays a backstop instead of the
          primary reconnect mechanism.
          """
          import time

          import sounddevice as sd

          INPUT_NAME = "${inputDevice}"
          OUTPUT_NAME = "${outputDevice}"
          SOURCE_CHANNEL = ${toString sourceChannel}
          SAMPLERATE = 48000
          # 256 frames @ 48 kHz is ~5.3 ms per block. Total added latency lands
          # around 15-25 ms, which is inaudible on a call and well short of the
          # point where it would bother anyone monitoring themselves.
          BLOCKSIZE = 256
          RETRY_SECONDS = 5


          def log(message):
              print(message, flush=True)


          def find_device(name, want_input):
              """Index of the first device whose name contains `name` and has
              channels in the requested direction."""
              key = "max_input_channels" if want_input else "max_output_channels"
              for index, device in enumerate(sd.query_devices()):
                  if name.lower() in device["name"].lower() and device[key] > 0:
                      return index
              return None


          def bridge():
              """One connection attempt. Returns when the stream stops for any
              reason; the caller retries."""
              # PortAudio caches the device list at initialisation, so it must
              # be torn down and rebuilt to notice hotplugs.
              sd._terminate()
              sd._initialize()

              source = find_device(INPUT_NAME, want_input=True)
              sink = find_device(OUTPUT_NAME, want_input=False)
              if source is None:
                  log("waiting for input device: " + INPUT_NAME)
                  return
              if sink is None:
                  log("waiting for output device: " + OUTPUT_NAME)
                  return

              def callback(indata, outdata, frames, time_info, status):
                  if status:
                      log("stream status: " + str(status))
                  mono = indata[:, SOURCE_CHANNEL]
                  outdata[:, 0] = mono
                  outdata[:, 1] = mono

              with sd.Stream(
                  device=(source, sink),
                  samplerate=SAMPLERATE,
                  blocksize=BLOCKSIZE,
                  dtype="float32",
                  channels=(2, 2),
                  latency="low",
                  callback=callback,
              ) as stream:
                  log("bridging " + INPUT_NAME + " ch" + str(SOURCE_CHANNEL + 1) + " -> " + OUTPUT_NAME + " (L+R)")
                  while stream.active:
                      time.sleep(1)
              log("stream ended")


          def main():
              while True:
                  try:
                      bridge()
                  except Exception as error:  # noqa: BLE001 - never exit on a transient CoreAudio fault
                      log("error: " + str(error))
                  time.sleep(RETRY_SECONDS)


          main()
        '';
    in
    {
      home.packages = [ mono-mic ];

      # KeepAlive is deliberately unconditional: the script already handles
      # device churn internally, so a process exit means something genuinely
      # unexpected happened and restarting is the right response.
      # ThrottleInterval keeps a persistent failure from becoming a hot loop.
      launchd.agents.mono-mic = {
        enable = true;
        config = {
          ProgramArguments = [ "${mono-mic}/bin/mono-mic" ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mono-mic.out.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mono-mic.err.log";
        };
      };
    };
}
