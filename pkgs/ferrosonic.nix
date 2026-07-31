# Ferrosonic-ng: terminal Subsonic/Navidrome client with bit-perfect audio.
# Rust + ratatui. Playback via mpv (JSON IPC), MPRIS2, optional cava visualizer,
# automatic PipeWire sample-rate switching. Vim-style j/k navigation.
#
# Builds on macOS too — the source has no target_os gates and its two Linux-only
# integrations degrade quietly rather than fail:
#   MPRIS2  → start_mpris_server() errors without a session bus; app logs a
#             warning and runs on (media keys just don't work).
#   PipeWire → the sample-rate switcher shells out to pw-metadata; the missing
#             binary is caught with .ok()/warn!, so playback is unaffected (no
#             automatic bit-perfect rate switching on macOS — set the rate in
#             Audio MIDI Setup, or run mpv in exclusive mode).
# cava is Linux-only here: on macOS it has no system audio source without a
# loopback device (BlackHole et al), so the wrapper leaves it off the PATH and
# the visualizer stays disabled.
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  dbus,
  makeBinaryWrapper,
  mpv,
  cava,
}:

let
  version = "0.8.2";

  # notify-rust exposes a different surface per backend, and ferrosonic only
  # writes to the XDG one: Hint and NotificationHandle::id() don't exist in the
  # macOS (mac-notification-sys) build, so the crate fails to compile there.
  # Swap in an equivalent that sticks to the portable subset — same public API,
  # minus notification replacement (macOS Notification Center coalesces per app
  # anyway) and the transient/category hints, which have no macOS analogue.
  darwinNotificationPatch = ''
    cat > src/app/notifications.rs <<'EOF'
    use notify_rust::Notification;
    use tracing::error;

    pub struct TrackInfo {
        pub title: String,
        pub artist: String,
        pub album: String,
    }

    pub fn notify_track_change(track: &TrackInfo) {
        if let Err(e) = Notification::new()
            .summary(&track.title)
            .body(&format!("{} — {}", track.artist, track.album))
            .show()
        {
            error!("Failed to show notification: {}", e);
        }
    }
    EOF
  '';
in
rustPlatform.buildRustPackage (
  {
    pname = "ferrosonic";
    inherit version;

    src = fetchFromGitHub {
      owner = "Jamie098";
      repo = "ferrosonic-ng";
      rev = "v${version}";
      hash = "sha256-ReKJxGusk106WF+spXeXgTAdIvnYMsLRcx55X1Lch3w=";
    };

    cargoHash = "sha256-aav2CRG4CCnGHEW7Ole1tttWV02ENBIDKOm5qHfnBMc=";

    nativeBuildInputs = [
      pkg-config
      makeBinaryWrapper
    ];

    buildInputs = [
      openssl # reqwest native-tls
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      dbus # MPRIS2
    ];

    # mpv is the playback engine (required); cava drives the visualizer
    # (optional, Linux only — ferrosonic probes for it with `which cava`).
    postInstall = ''
      wrapProgram $out/bin/ferrosonic \
        --prefix PATH : ${lib.makeBinPath ([ mpv ] ++ lib.optional stdenv.hostPlatform.isLinux cava)}
    '';

    meta = {
      description = "Terminal Subsonic/Navidrome client with bit-perfect audio, MPRIS2 and cava visualizer";
      homepage = "https://github.com/Jamie098/ferrosonic-ng";
      license = lib.licenses.mit;
      mainProgram = "ferrosonic";
      platforms = lib.platforms.unix;
    };
  }
  # Added conditionally rather than as an empty string, so the Linux derivation
  # hash is unchanged and Linux hosts don't rebuild.
  // lib.optionalAttrs stdenv.hostPlatform.isDarwin { postPatch = darwinNotificationPatch; }
)
