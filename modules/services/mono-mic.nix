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
# So the fix is done in software, in three parts:
#
#   1. BlackHole 2ch — a virtual audio device (a CoreAudio HAL plug-in). This
#      is the thing apps will select as their microphone. Installed by the
#      nix-darwin half below, because HAL plug-ins must live in
#      /Library/Audio/Plug-Ins/HAL, which is root-owned.
#
#   2. MonoMic.app — an application bundle with no interface, whose only job is
#      to hold the microphone permission. Also installed by the nix-darwin half,
#      as a signed copy in /Applications. See THE TCC PROBLEM below; this is the
#      part that took three days of silence to find.
#
#   3. mono-mic — a small launchd-supervised bridge that reads the Scarlett's
#      channel 1 and writes it to *both* channels of BlackHole. BlackHole is
#      only a pipe; on its own it duplicates nothing. This is the home-manager
#      half, and it runs *inside* MonoMic.app rather than on its own.
#
# After a rebuild, run `mono-mic-grant` once (see below), then pick
# "BlackHole 2ch" as the input device — system-wide in Sound settings, or
# per-app — and the mic is centred everywhere. `mono-mic-check` confirms audio
# is actually flowing.
#
# ── THE TCC PROBLEM, AND WHY THERE IS AN .APP BUNDLE ──────────────────────────
#
# macOS TCC will not grant microphone access to a bare executable in
# /nix/store. There is no bundle for Privacy & Security to list, no UI to prompt
# from, and the store path changes on every rebuild. What makes this expensive
# to diagnose is the failure mode: A DENIED CLIENT IS NOT TOLD SO. CoreAudio
# hands it a stream of digital silence instead of returning an error, so the
# bridge opens cleanly, the callback fires at full rate, PortAudio reports no
# faults, and every sample is exactly 0.0.
#
# Measured 2026-08-24, same script and same interpreter, two launch contexts:
#
#   from a terminal (inherits the terminal's own mic grant)
#     BlackHole rms L/R = 0.016619 / 0.016619    callback_frames = 293888
#   as a bare launchd agent
#     BlackHole rms L/R = 0.000000 / 0.000000    callback_frames = 395776
#
# Same frame counts, zero status errors on both sides. Only the samples differ.
# That is TCC, and nothing in the logs says so — which is why the bridge now
# watches for exact digital zero and says it out loud (SILENCE_ALERT_SECONDS).
#
# The bundle is built by pkgs/mono-mic-app. Its main executable is a tiny Mach-O
# shim, and both of those words are load-bearing:
#
#   * MACH-O, not a script, because TCC resolves a request against the process's
#     code identity — a script's identity is its interpreter, so the grant would
#     land on /bin/sh instead of on this bundle.
#
#   * TINY AND STORE-PATH-FREE, because an ad-hoc signature gives TCC a
#     cdhash-based designated requirement, so anything that changes the bundle
#     revokes the grant. The shim names no store path; it reads the command to
#     run from `commandFile` below, which lives outside the bundle and is
#     rewritten freely on every rebuild.
#
# The payoff is a grant that survives `rebuildhm`. VERIFIED 2026-08-24: the
# derivation is bit-reproducible (`nix build --rebuild` clean), and two
# independent `codesign --sign -` runs both produced
# `cdhash H"e61ef7d62f315934c4dfa6308f3bfd33d15e417e"`. The cdhash only moves if
# pkgs/mono-mic-app/{shim.c,Info.plist} or the C compiler changes — at which
# point re-grant by hand, the same treadmill modules/desktop/yabai.nix documents
# for its Accessibility grant.
#
# The shim FORKS rather than exec'ing. execv would replace the image in-place,
# leaving the process carrying Python's identity and no grant; forking keeps the
# signed shim alive as the parent, so the child inherits it as its TCC
# "responsible process". That is the same mechanism that lets a CLI tool run in
# Terminal.app borrow Terminal's microphone grant. VERIFIED: shim parent +
# Python child, BlackHole rms L/R = 0.001912 / 0.001912.
#
# Trade-off worth knowing: apps now capture BlackHole rather than the Scarlett,
# so if the bridge dies the mic goes silent. launchd keeps it alive and the
# script reconnects on its own when the interface is unplugged and returns, but
# it is a moving part that a hardware "Combine Inputs" switch would not be.
#
# ── SAMPLE RATE ───────────────────────────────────────────────────────────────
#
# The bridge follows the *input device's* native rate rather than pinning 48 kHz.
# Pinning was the original choice and it was wrong: the Scarlett sat at 44100
# while the stream ran at 48000, so PortAudio resampled across an 8.8% error and
# filled the log with 10,930 `input overflow` lines. Opening at the device's own
# rate measured clean (zero status lines at both 44100 and 48000), and BlackHole
# is virtual — it adopts whatever rate the stream asks for.
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

  # /Applications rather than /Applications/Nix Apps: nix-darwin rsyncs its own
  # tree into the latter on every activation, which would fight the signature
  # applied below. This bundle is copied and signed by hand instead, so it needs
  # a location nix-darwin does not manage.
  appName = "MonoMic.app";
  appPath = "/Applications/${appName}";
  bundleId = "com.jevin.mono-mic";

  # Read by the shim at startup, relative to $HOME. MUST match COMMAND_FILE in
  # pkgs/mono-mic-app/shim.c — the two are a contract, and nothing checks it at
  # build time. One argument per line, so no quoting rules have to be agreed on.
  commandFile = "Library/Application Support/mono-mic/command";
in
{
  # ── Half 1: the virtual device, and the bundle that holds the grant ───────
  flake.modules.darwin.monoMic =
    { pkgs, ... }:
    let
      # nixpkgs' blackhole defaults to a 256-channel build; 2ch is what we want
      # for a microphone, and it keeps the device out of the way in app pickers
      # that enumerate every channel.
      blackhole = pkgs.blackhole.override { channel = "2ch"; };
      driver = "${blackhole}/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver";

      monoMicApp = pkgs.callPackage ../../pkgs/mono-mic-app { };
      appSource = "${monoMicApp}/Applications/${appName}";
    in
    {
      # Both bundles are *copied* rather than symlinked into place. For the HAL
      # plug-in, coreaudiod loads it as root very early and a driver that
      # depends on /nix being present and readable at that moment is a
      # boot-order risk for no benefit. For MonoMic.app, TCC cannot hold a grant
      # against a symlink into the store at all, and the copy has to be writable
      # so codesign can seal it.
      #
      # The stamp files record which store path each copy came from, so
      # activation is idempotent — coreaudiod is only restarted (which briefly
      # interrupts all audio) when the driver actually changes, and the app is
      # only re-signed when the bundle does.
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

        echo "setting up ${appName} (mono-mic microphone grant)..." >&2
        appStampDir="/Library/Application Support/mono-mic"
        appStamp="$appStampDir/.app-nix-source"

        if [ ! -e "${appPath}" ] || [ "$(cat "$appStamp" 2>/dev/null)" != "${appSource}" ]; then
          mkdir -p "$appStampDir"
          rm -rf "${appPath}"
          cp -R "${appSource}" "${appPath}"
          chmod -R u+w "${appPath}"
          chown -R root:wheel "${appPath}"
          # Ad-hoc, with the identifier pinned to CFBundleIdentifier so TCC and
          # the signature agree. /usr/bin/codesign and not nixpkgs' sigtool:
          # sigtool is a partial reimplementation that does not seal bundle
          # resources, and TCC needs a real bundle signature. Deterministic —
          # an ad-hoc signature carries no timestamp, so the cdhash is a pure
          # function of the bytes.
          /usr/bin/codesign --force --sign - --identifier "${bundleId}" "${appPath}"
          echo "${appSource}" > "$appStamp"
          echo "  installed and signed; run 'mono-mic-grant' if the mic is silent" >&2
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

          import numpy as np
          import sounddevice as sd

          INPUT_NAME = "${inputDevice}"
          OUTPUT_NAME = "${outputDevice}"
          SOURCE_CHANNEL = ${toString sourceChannel}
          # Tried in order. The input device's own rate goes first (see the
          # module header on sample rate); these are the fallbacks for a device
          # that reports something the virtual sink will not take.
          FALLBACK_SAMPLERATES = (48000, 44100)
          # 256 frames @ 48 kHz is ~5.3 ms per block. Total added latency lands
          # around 15-25 ms, which is inaudible on a call and well short of the
          # point where it would bother anyone monitoring themselves.
          BLOCKSIZE = 256
          RETRY_SECONDS = 5
          # A repeated message is printed once, then at most this often with a
          # count. Without this, one stuck stream wrote 10,930 identical
          # `input overflow` lines and a 1.1 MB log.
          REPEAT_SUMMARY_SECONDS = 60
          # How long every sample may be *exactly* zero before saying so. Real
          # input always carries a noise floor — the Solo's unused channel 2
          # still measures ~2.4e-05 — so exact digital zero means the samples
          # are synthetic, which in practice means a missing TCC grant.
          SILENCE_ALERT_SECONDS = 30

          _last_message = None
          _repeat_count = 0
          _last_emit = 0.0

          # Written by the audio callback, read and reset by the monitor loop.
          # A plain float, because the callback runs on a real-time thread where
          # allocating or locking is how you get dropouts.
          _input_peak = 0.0


          def log(message):
              """Print, collapsing immediate repeats into a periodic count."""
              global _last_message, _repeat_count, _last_emit
              now = time.monotonic()
              if message == _last_message:
                  _repeat_count += 1
                  if now - _last_emit >= REPEAT_SUMMARY_SECONDS:
                      print(message + " (x" + str(_repeat_count) + " in " + str(int(now - _last_emit)) + "s)", flush=True)
                      _repeat_count = 0
                      _last_emit = now
                  return
              if _repeat_count:
                  print(_last_message + " (x" + str(_repeat_count) + " more)", flush=True)
              _last_message = message
              _repeat_count = 0
              _last_emit = now
              print(message, flush=True)


          def find_device(name, want_input):
              """Index of the first device whose name contains `name` and has
              channels in the requested direction."""
              key = "max_input_channels" if want_input else "max_output_channels"
              for index, device in enumerate(sd.query_devices()):
                  if name.lower() in device["name"].lower() and device[key] > 0:
                      return index
              return None


          def candidate_samplerates(source):
              """The input device's native rate first, then the fallbacks."""
              rates = []
              try:
                  native = int(sd.query_devices(source)["default_samplerate"])
                  if native > 0:
                      rates.append(native)
              except Exception as error:  # noqa: BLE001 - a bad rate is not fatal
                  log("could not read native rate: " + str(error))
              for rate in FALLBACK_SAMPLERATES:
                  if rate not in rates:
                      rates.append(rate)
              return rates


          def callback(indata, outdata, frames, time_info, status):
              global _input_peak
              if status:
                  log("stream status: " + str(status))
              mono = indata[:, SOURCE_CHANNEL]
              peak = float(np.abs(mono).max())
              if peak > _input_peak:
                  _input_peak = peak
              outdata[:, 0] = mono
              outdata[:, 1] = mono


          def monitor(stream):
              """Tick once a second while the stream runs, watching for the
              silent-but-healthy state that a missing microphone grant produces."""
              global _input_peak
              silent_seconds = 0
              alerted = False
              while stream.active:
                  time.sleep(1)
                  peak = _input_peak
                  _input_peak = 0.0
                  if peak == 0.0:
                      silent_seconds += 1
                      if silent_seconds >= SILENCE_ALERT_SECONDS and not alerted:
                          # Adjacent string literals rather than leading "+"
                          # continuations, which flake8 rejects as W503.
                          log(
                              "WARNING: " + str(silent_seconds) + "s of exact digital silence from " + INPUT_NAME + " — "
                              "the stream is healthy but every sample is 0.0. That is what macOS returns when the "
                              "microphone permission is missing. Run 'mono-mic-grant' and allow MonoMic under "
                              "Privacy & Security > Microphone."
                          )
                          alerted = True
                  else:
                      if alerted:
                          log("input recovered: signal is flowing again")
                      silent_seconds = 0
                      alerted = False


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

              rates = candidate_samplerates(source)
              for rate in rates:
                  try:
                      stream = sd.Stream(
                          device=(source, sink),
                          samplerate=rate,
                          blocksize=BLOCKSIZE,
                          dtype="float32",
                          channels=(2, 2),
                          latency="low",
                          callback=callback,
                      )
                  except Exception as error:  # noqa: BLE001 - try the next rate
                      log("cannot open at " + str(rate) + " Hz: " + str(error))
                      continue
                  with stream:
                      log("bridging " + INPUT_NAME + " ch" + str(SOURCE_CHANNEL + 1) + " -> " + OUTPUT_NAME + " (L+R) at " + str(rate) + " Hz")
                      monitor(stream)
                  log("stream ended")
                  return
              log("no usable sample rate among " + str(rates))


          def main():
              while True:
                  try:
                      bridge()
                  except Exception as error:  # noqa: BLE001 - never exit on a transient CoreAudio fault
                      log("error: " + str(error))
                  time.sleep(RETRY_SECONDS)


          main()
        '';

      # Opens the one pane that cannot be automated, and says what to do in it.
      # The grant is per-bundle and there is no supported CLI for it: `tccutil`
      # can only reset, not add.
      mono-mic-grant = pkgs.writeShellScriptBin "mono-mic-grant" ''
        set -euo pipefail

        if [ ! -d "${appPath}" ]; then
          echo "${appPath} is missing — run rebuildhm first." >&2
          exit 1
        fi

        echo "Opening Privacy & Security > Microphone."
        echo
        echo "Allow \"MonoMic\" in the list. If it is not listed yet, click \"+\" and"
        echo "choose:"
        echo
        echo "    ${appPath}"
        echo
        echo "The file picker hides /Applications entries it does not consider"
        echo "apps; Shift-Cmd-G pastes the path directly."
        echo
        echo "Then restart the bridge and confirm audio is flowing:"
        echo
        echo "    launchctl kickstart -k gui/$(id -u)/org.nix-community.home.mono-mic"
        echo "    mono-mic-check"
        echo

        open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
      '';

      # The bridge failing silently is the whole reason this module has a
      # history, so verifying it is a first-class command rather than a
      # remembered one-liner.
      mono-mic-check = pkgs.writers.writePython3Bin "mono-mic-check"
        {
          libraries = with pkgs.python3Packages; [
            sounddevice
            numpy
          ];
          flakeIgnore = [ "E501" ];
        }
        ''
          """Report whether the mono bridge is actually carrying audio.

          Distinguishes the three states that all look alike in the log: no
          device, real signal, and the exact digital zero of a missing
          microphone grant.
          """
          import sys

          import numpy as np
          import sounddevice as sd

          OUTPUT_NAME = "${outputDevice}"
          SECONDS = 2


          def find_input(name):
              for index, device in enumerate(sd.query_devices()):
                  if name.lower() in device["name"].lower() and device["max_input_channels"] > 0:
                      return index, device
              return None, None


          def main():
              index, device = find_input(OUTPUT_NAME)
              if index is None:
                  print(OUTPUT_NAME + " not found — is the HAL plug-in installed?")
                  return 1

              rate = int(device["default_samplerate"])
              print("recording " + str(SECONDS) + "s from " + OUTPUT_NAME + " at " + str(rate) + " Hz...")
              recording = sd.rec(int(rate * SECONDS), samplerate=rate, channels=2, device=index, dtype="float32")
              sd.wait()

              rms = np.sqrt((recording ** 2).mean(axis=0))
              peak = np.abs(recording).max(axis=0)
              print("  rms  L/R = {:.6f} / {:.6f}".format(rms[0], rms[1]))
              print("  peak L/R = {:.6f} / {:.6f}".format(peak[0], peak[1]))

              if peak[0] == 0.0 and peak[1] == 0.0:
                  print("")
                  print("SILENT — every sample is exactly 0.0.")
                  print("The bridge is almost certainly running without a microphone grant.")
                  print("Run 'mono-mic-grant', allow MonoMic, then restart the agent:")
                  print("  launchctl kickstart -k gui/$(id -u)/org.nix-community.home.mono-mic")
                  return 1

              if abs(float(rms[0]) - float(rms[1])) > 1e-9:
                  print("")
                  print("WARNING: channels differ, so this is not the mono bridge's output.")
                  print("Something else may be writing to " + OUTPUT_NAME + ".")
                  return 1

              print("")
              print("OK — signal present and centred (L and R identical).")
              return 0


          sys.exit(main())
        '';
    in
    {
      home.packages = [
        mono-mic
        mono-mic-grant
        mono-mic-check
      ];

      # The shim's indirection, and the reason the microphone grant outlives a
      # rebuild: this file changes whenever the bridge's store path does, while
      # the signed bundle that reads it does not.
      home.file.${commandFile}.text = ''
        ${mono-mic}/bin/mono-mic
      '';

      # KeepAlive is deliberately unconditional: the script already handles
      # device churn internally, so a process exit means something genuinely
      # unexpected happened and restarting is the right response.
      # ThrottleInterval keeps a persistent failure from becoming a hot loop.
      #
      # ProgramArguments points at the *bundle*, not at ${mono-mic} — that
      # indirection is the entire fix. launchd runs the signed shim, the shim
      # forks the bridge, and the bridge inherits the bundle's microphone grant.
      # Pointing this back at the store path directly reintroduces three days of
      # silent zeros.
      launchd.agents.mono-mic = {
        enable = true;
        config = {
          ProgramArguments = [ "${appPath}/Contents/MacOS/mono-mic" ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/mono-mic.out.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/mono-mic.err.log";
        };
      };
    };
}
