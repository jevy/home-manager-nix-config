# The Claude Code skill for hunk — upstream's own, plus a local section.
#
# hunk ships `skills/hunk-review/SKILL.md` inside its package, so this takes it
# from the SAME derivation that provides the binary: the skill and the CLI it
# documents can never drift.
#
# ── Append, don't replace ────────────────────────────────────────────────────
# The opposite call from pkgs/claude-skill-tuicr, deliberately. Upstream's tuicr
# skill had to be REPLACED because it actively misroutes here ("use tuicr by
# default"). Upstream's hunk skill misroutes nothing — it is simply unaware of
# this machine's keybindings, of tuicr, and of git-spice. So its body is kept
# verbatim and local.md is appended, which means an upstream rewrite lands
# whole on the next `nix flake update hunk` instead of silently going stale
# behind a fork.
{
  lib,
  stdenvNoCC,
  hunk,
}:
stdenvNoCC.mkDerivation {
  pname = "claude-skill-hunk";
  inherit (hunk) version;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    src=${hunk}/skills/hunk-review/SKILL.md
    # Fail loudly if upstream moves it: an empty skill directory looks like a
    # working install right up until an agent needs it.
    if [ ! -f "$src" ]; then
      echo "error: skills/hunk-review/SKILL.md is gone from the hunk package" >&2
      exit 1
    fi

    mkdir -p $out
    cat "$src" ${./local.md} > $out/SKILL.md

    runHook postInstall
  '';

  meta = {
    description = "Claude Code skill for hunk — upstream's, plus this setup's review routing";
    homepage = "https://github.com/modem-dev/hunk";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
