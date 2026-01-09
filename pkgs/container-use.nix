{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "container-use";
  version = "0.4.2";

  src = fetchFromGitHub {
    owner = "dagger";
    repo = "container-use";
    rev = "v${version}";
    hash = "sha256-YKgS142a9SL1ZEjS+VArxwUzQX961zwlGuHW43AMxQA=";
  };

  vendorHash = "sha256-M7YhEm9Gmjv2gxB2r7AS5JLLThEkvtJfLBrB+cvsN5c=";

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
