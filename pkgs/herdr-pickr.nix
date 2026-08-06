# herdr-pickr — a herdr plugin: Ctrl+click a GitHub PR / GitLab MR link in any
# pane and pick how to review it (tuicr, hunk, plain diff, browser).
#
# Upstream is a plain script directory, not a flake: a `herdr-plugin.toml`
# manifest plus four bash/python scripts under `bin/`. herdr registers a plugin
# by absolute path (`herdr plugin link <dir>`), so all this derivation does is
# stage that directory into the store with the scripts executable and their
# shebangs pointed at Nix's bash/python3.
#
# `install.sh` (upstream's `[[build]]` hook) only chmod +x's bin/ and prints
# setup hints — the chmod happens here instead, and `herdr plugin link` doesn't
# run build hooks anyway, so the hook is deliberately unused.
#
# Runtime deps stay on PATH rather than being wrapped in: the reviewer commands
# come from the user's `config.toml` (`tuicr pr {url}`, `gh pr diff … | hunk …`),
# so which binaries are needed is a user-config question. herdr-pickr hides any
# reviewer whose `needs` binaries are missing. modules/dev/herdr.nix installs the
# ones its config.toml references.
{
  lib,
  stdenvNoCC,
  src,
  bash,
  python3,
}:
stdenvNoCC.mkDerivation {
  pname = "herdr-pickr";
  # Upstream ships no tags; version tracks `version` in herdr-plugin.toml.
  version = "0.1.2";
  inherit src;

  nativeBuildInputs = [ bash ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r herdr-plugin.toml bin config $out/
    chmod +x $out/bin/*
    # patchShebangs (fixupPhase) rewrites the bash scripts, but pickr-config's
    # `#!/usr/bin/env python3` is pinned by hand: macOS has no python3 unless the
    # Xcode command line tools are installed, and the script needs 3.11+ for
    # tomllib.
    substituteInPlace $out/bin/pickr-config \
      --replace-fail "#!/usr/bin/env python3" "#!${python3}/bin/python3"
    runHook postInstall
  '';

  meta = {
    description = "herdr plugin routing PR/MR link clicks to a reviewer (tuicr, hunk, diff, browser)";
    homepage = "https://github.com/tomasvarga/herdr-pickr";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
