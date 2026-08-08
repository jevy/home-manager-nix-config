# The Claude Code skill for hunk — upstream's own, plus a local section.
#
# hunk ships `skills/hunk-review/SKILL.md` inside its package, so this takes it
# from the SAME derivation that provides the binary: the skill and the CLI it
# documents can never drift.
#
# ── Wrap, don't fork ─────────────────────────────────────────────────────────
# The opposite call from pkgs/claude-skill-tuicr, deliberately. Upstream's tuicr
# skill had to be REPLACED because it actively misroutes here ("use tuicr by
# default"). Upstream's hunk skill misroutes nothing — it is simply unaware of
# this machine's keybindings, of tuicr, and of git-spice. So its BODY is kept
# verbatim between top.md and local.md, and an upstream rewrite lands whole on
# the next `nix flake update hunk` instead of going stale behind a fork.
#
# ── Why the frontmatter IS replaced ──────────────────────────────────────────
# Upstream's description is two SDO violations that matter here:
#
#   1. It summarises the workflow ("inspects… navigates… reloads… adds"), which
#      is the documented failure mode where an agent follows the description
#      instead of reading the body.
#   2. It triggers on "the user has a Hunk session running" — but the most
#      important local content is the ROUTING rule (local diff → hunk, not
#      tuicr), which has to fire when no session exists yet. That is the moment
#      the tool gets chosen. Triggering after the session is open means the
#      skill loads only once the decision it informs has already been made.
#
# Frontmatter is a two-line surface, so overriding it risks far less drift than
# forking the body — and it is the part that is actually wrong for this machine.
# top.md therefore carries the frontmatter plus the routing rule and the
# user/agent note trap, both hoisted to the top where they are read; local.md
# keeps the longer reference detail.
#
# Upstream's own frontmatter is stripped by dropping everything through the
# second `---`.
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

    # Strip upstream's frontmatter: delete through the second '---'. Guard on
    # it having had one, so a reshaped upstream file fails here rather than
    # shipping a skill with two frontmatter blocks (or none).
    if [ "$(head -1 "$src")" != "---" ]; then
      echo "error: upstream SKILL.md no longer starts with YAML frontmatter" >&2
      exit 1
    fi
    body="$(awk 'NR>1 && /^---$/ {found=1; next} found' "$src")"
    if [ -z "$body" ]; then
      echo "error: upstream SKILL.md body is empty after stripping frontmatter" >&2
      exit 1
    fi

    mkdir -p $out
    {
      cat ${./top.md}
      printf '%s\n' "$body"
      cat ${./local.md}
    } > $out/SKILL.md

    runHook postInstall
  '';

  meta = {
    description = "Claude Code skill for hunk — upstream's, plus this setup's review routing";
    homepage = "https://github.com/modem-dev/hunk";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
