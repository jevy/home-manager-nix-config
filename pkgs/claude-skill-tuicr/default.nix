# The Claude Code skill for tuicr, assembled from two sources:
#
#   * the wrapper scripts come from `inputs.tuicr` — the SAME pin that builds
#     the tuicr binary. They shell out to `tuicr` and to `herdr pane` sub-
#     commands, so pinning them together is the point: `nix flake update tuicr`
#     moves the binary and its wrappers as a unit. Vendoring copies into this
#     repo would let them drift.
#
#   * SKILL.md is ours and REPLACES upstream's. Upstream's opens with "use
#     `tuicr review` as the default agent interface", which is wrong here:
#     this setup splits review three ways (see modules/dev/herdr.nix) and tuicr
#     is specifically the forge reviewer. reviewr owns local agent diffs, and
#     its comments never appear in a tuicr session. Shipping upstream's file
#     verbatim trains the agent to reach for tuicr on local diffs, where it
#     cannot send comments back.
{
  lib,
  stdenvNoCC,
  src,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-skill-tuicr";
  version = "unstable";

  inherit src;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    # Fail loudly if upstream moves the skill: a silently empty skill directory
    # would look like a working install right up until an agent needed it.
    if [ ! -d skills/tuicr ]; then
      echo "error: skills/tuicr is gone from the tuicr input; check upstream layout" >&2
      exit 1
    fi

    mkdir -p $out
    for w in tuicr-wrapper-herdr.sh tuicr-wrapper.sh tuicr-wrapper-zellij.sh; do
      if [ ! -f "skills/tuicr/$w" ]; then
        echo "error: expected wrapper skills/tuicr/$w not found upstream" >&2
        exit 1
      fi
      install -m 0755 "skills/tuicr/$w" "$out/$w"
    done

    install -m 0644 ${./SKILL.md} $out/SKILL.md

    runHook postInstall
  '';

  # The wrappers are `#!/usr/bin/env bash`. Default fixup only patches $out/bin
  # and friends, so do it explicitly. Only the shebang is rewritten — the
  # wrappers resolve `tuicr`, `herdr` and `jq` from PATH at runtime on purpose,
  # so they follow the user's profile rather than a build-time pin.
  postFixup = ''
    patchShebangs $out
  '';

  meta = {
    description = "Claude Code skill for tuicr, wired to this setup's herdr review split";
    homepage = "https://github.com/agavra/tuicr";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
