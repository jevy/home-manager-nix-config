# Beads issue tracker (built from upstream flake source)
{ inputs, ... }:
{
  flake.modules.homeManager.beads =
    { pkgs, lib, ... }:
    let
      beads = pkgs.buildGoModule {
        pname = "beads";
        version = inputs.beads.shortRev or "dev";
        src = inputs.beads;
        subPackages = [ "cmd/bd" ];
        doCheck = false;
        vendorHash = "sha256-yiKBBUqR28wFr+QvVfluzUoNl6Gdkt9KN8X+hFY+2I0=";
        # The go-modules FOD has network access, so GOTOOLCHAIN=auto lets Go
        # download the toolchain version that dependencies require (1.25.6).
        overrideModAttrs = _: {
          env.GOTOOLCHAIN = "auto";
          env.HOME = "/tmp";
          # Remove test files referencing non-existent internal/rpc package
          postPatch = "find . -name '*_test.go' -delete";
        };
        postPatch = ''
          goVer="$(go env GOVERSION | sed 's/^go//')"
          sed -i "s/^go .*/go $goVer/" go.mod
        '';
        # Patch vendor/modules.txt after configurePhase copies the vendor dir
        preBuild = ''
          goVer="$(go env GOVERSION | sed 's/^go//')"
          chmod -R u+w vendor
          sed -i "s/go [0-9]\+\.[0-9]\+\.[0-9]\+/go $goVer/g" vendor/modules.txt
        '';
        nativeBuildInputs = [ pkgs.git pkgs.pkg-config ];
        buildInputs = [ pkgs.icu ];
        meta = {
          description = "An issue tracker designed for AI-supervised coding workflows";
          homepage = "https://github.com/steveyegge/beads";
          license = pkgs.lib.licenses.mit;
          mainProgram = "bd";
        };
      };
    in
    {
      home.packages = [ beads ];
    };
}
