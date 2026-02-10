{
  lib,
  buildGo124Module,
  fetchFromGitHub,
}:

buildGo124Module rec {
  pname = "container-use";
  version = "0-unstable-2025-10-07";

  src = fetchFromGitHub {
    owner = "dagger";
    repo = "container-use";
    rev = "725081899774b5e0ee82a56bf704afc0cb39e0ec";
    hash = "sha256-Liq457BxRa8Wo3xtD0mmDjUHV9PPkQhCmnHPWQomiMw=";
  };

  vendorHash = "sha256-Xh2BKTbSvjfrsKDZy5mea6t6sQIRMTDEqrdDY45nky4=";

  subPackages = [ "cmd/container-use" ];

  # Tests require git and network access
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = {
    description = "Containerized environments for coding agents";
    homepage = "https://github.com/dagger/container-use";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "container-use";
  };
}
