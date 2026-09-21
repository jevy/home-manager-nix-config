# OBS Studio config (backup, not declarative)

OBS owns `~/.config/obs-studio` and rewrites it on every exit, so it cannot be
managed by home-manager without fighting the app. Nix installs OBS and its
plugins (`modules/desktop/apps.nix`); these files are a **snapshot** of the
settings, committed so a bad exit or a fresh machine doesn't cost the tuning.

Copy them back by hand, **with OBS closed** (it overwrites on exit):

```
cp obs/basic.ini           ~/.config/obs-studio/basic/profiles/Untitled/basic.ini
cp obs/recordEncoder.json  ~/.config/obs-studio/basic/profiles/Untitled/recordEncoder.json
cp obs/scene-Untitled.json ~/.config/obs-studio/basic/scenes/Untitled.json
```

Check OBS is actually closed with `pgrep -x .obs-wrapped`, **not** `pgrep -x obs`.
On NixOS the binary is wrapped, so the process is named `.obs-wrapped` and the
obvious check silently reports "not running" while OBS is very much running.

`plugin_config/obs-websocket/config.json` is deliberately not here: it holds
`server_password`.

## Why the settings are what they are

Recording rig: Elgato Cam Link 4K (camera over HDMI, 1080p59.94), Focusrite
Scarlett Solo (XLR mic), Hyprland/Wayland. Output target is YouTube screencasts.

| Choice | Reason |
|---|---|
| Canvas 1920x1080, output 1920x1080 | The Cam Link caps at 1080p, so 1:1 with no scaling. Was 3840x2400 -> 1727x1080, which double-resampled and used an odd (invalid for 4:2:0) width. |
| FPS fractional 60000/1001 (59.94) | Exactly matches the camera's `7013/117`. Plain `60` drifts against it and dupes a frame every ~16s; plain `30` halves a live camera and reads as laggy. |
| Camera source is `v4l2_input`, **not** `pipewire-camera-source` | The PipeWire camera portal re-enumerates every PipeWire node that appears (audio sinks, VLC, even `paplay`) and pauses/restarts the camera stream each time. 15 pauses in one session, ~57ms each, which accumulated into progressive A/V drift. V4L2 talks to `/dev/video5` directly and never sees the portal. |
| `buffering: false` on the camera | Async buffering adds its own drift on a capture card. |
| Mic is the **global** `Mic/Aux`, pinned to the Scarlett by device id | OBS only mixes audio from sources in the *active* scene. A per-scene mic source goes silent the moment you switch scenes. Globals are live in every scene. Pinned by id rather than `default` so a USB reconnect can't swap the mic. |
| `flags: 2` on Mic/Aux (force mono) | Belt and braces. The Scarlett's HiFi UCM profile already exposes Mic1 as a discrete 1-channel source (Mic2 is the unused instrument jack), so there is no stereo pair; this just guarantees nothing downstream pans it off-centre. |
| RNNoise -> Compressor (4:1, -18dB, +1dB makeup) -> Limiter (-3dB) | Compressor shapes, limiter is for emergencies only. Verified working: LRA dropped 11.8 -> 7.8 LU with peaks at -4.3dBFS, below the limiter. |
| `RecTracks=3` (tracks 1+2) | Track 1 mix, track 2 isolated mic. Desktop audio is off (muted *and* `mixers: 0`). |
| Program encoder x264 CRF 18 veryfast, hybrid_mp4 | Hybrid MP4 survives a crash, so no MKV-then-remux dance. |
| ISO recording via `source_record_filter` on each source | Raw per-source masters for editing in Descript; the program file is the reference edit. `record_mode: 3` fires them with the main recording. |
| ISOs write to `iso/%CCYY-%MM-%DD_%hh-%mm-%ss/{camera,screen}.mp4` | Per-take folders. The plugin calls `os_mkdirs`, so a subdirectory in `filename_formatting` works. Each filter stamps its own time, so a take starting on a second boundary can rarely split into two folders. |
| `frame_rate_divisor: 2` on the **screen** ISO only | Three simultaneous encodes at 59.94 cost 16.8% of frames to compositor stalls. Halving just the screen ISO's encode rate took that to 2.3% over an 18-minute take while the camera and program stay 59.94. |
| `scale: false` on both ISOs | Screen ISO keeps its native 2844x1714 while the program is 1080p, which is ~1.5x punch-in headroom for sharp zooms in post. That headroom is the whole point of the screen ISO. |
| Screen ISO has **no audio** (`audio_track: 0`) | See "the 33ms echo" below. The camera ISO keeps audio; the screen ISO is video-only. |
| Camera crop lives on the **scene items**, not on the source | A source-level crop would bake into `camera.mp4` too. Cropping the scene item keeps the ISO full-frame so the shot can be reframed per-cut in the edit. |

Recordings go to `~/Documents/obsrecordings` (program) and `iso/` (masters).
Capture level is deliberately ~-24 LUFS; normalise to -14 LUFS at export.

## The 33 ms echo

Both ISOs originally carried the `Mic/Aux` feed, so Descript could waveform-sync
them and offer "combine into sequence" automatically. That produced an audible
echo in every project, and the cause is specific:

```
screen.mp4 audio is offset from camera.mp4 by -33.4 ms
33.367 ms = exactly one frame at 29.97 fps
```

`frame_rate_divisor: 2` makes the screen ISO timestamp its audio against its own
halved video clock, so the audio lands exactly one of its frames late. It shows
up in the container too: camera video runs `1070.719650` against screen's
`1070.686283`, a difference of precisely 33.367 ms.

For **video** that is 1 frame at 29.97 (2 at 59.94), imperceptible; the angles
are fine. For **audio** 33 ms is textbook slapback delay, which is how you build
an echo effect deliberately.

Fixing it in the NLE is a per-project chore, and "Detach audio" leaves an
orphaned audio clip behind that keeps echoing. So the screen ISO is video-only
at the source instead. The cost is losing Descript's automatic combine prompt:
select both files and use **Create sequence** from the right-click menu, one
click.

To strip audio from a take recorded before this change, losslessly:

```
ffmpeg -i screen.mp4 -map 0:v -c copy screen-noaudio.mp4
```
