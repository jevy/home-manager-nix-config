# Ratune: vim-driven terminal music player for Subsonic/Navidrome servers
# Rust + ratatui. Audio via rodio (no mpv). Album art, FFT visualizer,
# synced lyrics (LRCLib), fzf/sk fuzzy picker, MPRIS via playerctl.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  alsa-lib,
  dbus,
  openssl,
  makeBinaryWrapper,
  fzf,
}:

rustPlatform.buildRustPackage rec {
  pname = "ratune";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "acmagn";
    repo = "ratune";
    rev = "v${version}";
    hash = "sha256-2zW7uVyByXKbnJUuCtqGzGecssKPt7iBWiiFwg9rVjE=";
  };

  cargoHash = "sha256-F3SXHxnt49QhrEyJrljNyt/gFm2eWTa+DMKb2Xmag6w=";

  nativeBuildInputs = [
    pkg-config
    makeBinaryWrapper
  ];

  buildInputs = [
    alsa-lib # rodio playback
    dbus # MPRIS + scrobble keyring
    openssl # reqwest native-tls (HTTP to server, LRCLib)
  ];

  # The optional library fuzzy picker shells out to fzf/sk; put fzf on PATH.
  postInstall = ''
    wrapProgram $out/bin/ratune \
      --prefix PATH : ${lib.makeBinPath [ fzf ]}
  '';

  meta = {
    description = "Vim-driven terminal music player for Subsonic/Navidrome (album art, visualizer, synced lyrics)";
    homepage = "https://github.com/acmagn/ratune";
    license = lib.licenses.mit;
    mainProgram = "ratune";
    platforms = lib.platforms.unix;
  };
}
