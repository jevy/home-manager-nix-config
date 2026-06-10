# Ferrosonic-ng: terminal Subsonic/Navidrome client with bit-perfect audio.
# Rust + ratatui. Playback via mpv (JSON IPC), MPRIS2, optional cava visualizer,
# automatic PipeWire sample-rate switching. Vim-style j/k navigation.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  dbus,
  makeBinaryWrapper,
  mpv,
  cava,
}:

rustPlatform.buildRustPackage rec {
  pname = "ferrosonic";
  version = "0.8.2";

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
    dbus # MPRIS2
  ];

  # mpv is the playback engine (required); cava drives the visualizer (optional).
  postInstall = ''
    wrapProgram $out/bin/ferrosonic \
      --prefix PATH : ${lib.makeBinPath [ mpv cava ]}
  '';

  meta = {
    description = "Terminal Subsonic/Navidrome client with bit-perfect audio, MPRIS2 and cava visualizer";
    homepage = "https://github.com/Jamie098/ferrosonic-ng";
    license = lib.licenses.mit;
    mainProgram = "ferrosonic";
    platforms = lib.platforms.linux;
  };
}
