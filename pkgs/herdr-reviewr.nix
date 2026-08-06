# herdr-reviewr — a herdr plugin: a sidebar pane showing the agent's diff
# (uncommitted / branch / last turn), where selected lines get comments that `s`
# sends straight back to the agent's input.
#
# Unlike herdr-pickr this is not a script directory — it's a Rust TUI binary plus
# a bash host (`herdr/pane.sh`) that herdr invokes for the actions and the
# `worktree.created` event. Upstream ships no flake, but `Cargo.lock` is
# committed, so `cargoLock.lockFile` vendors the tree with no vendor hash to
# maintain by hand.
#
# ── Why not upstream's installer ─────────────────────────────────────────────
# The manifest's `[[build]]` hook (`herdr/install.sh`) curls a prebuilt binary
# from the matching GitHub release into `$out/bin`. `herdr plugin link` skips
# build hooks, and a network fetch in a derivation wouldn't work anyway, so the
# binary is built from source here instead. Upstream anticipates exactly this
# ("for a local checkout, build it yourself with `cargo install --path .`").
#
# ── Layout matters ───────────────────────────────────────────────────────────
# The manifest hardcodes runtime paths relative to the plugin root:
#   [[panes]]  → sh -c exec "$HERDR_PLUGIN_ROOT/bin/herdr-reviewr"
#   actions    → bash herdr/pane.sh {toggle,open,close,auto-open}
# So the store path must be a *plugin directory* — herdr-plugin.toml at the top,
# `herdr/` beside it, and the binary at `bin/herdr-reviewr` — not a bare package.
# buildRustPackage already installs to $out/bin, so postInstall only adds the
# manifest and the host scripts.
#
# ── PATH ─────────────────────────────────────────────────────────────────────
# herdr runs plugin commands with a minimal PATH. pane.sh compensates by
# prepending Homebrew and /usr paths, which finds jq and git on a stock mac but
# not on NixOS and not under nix-darwin. Rather than depend on the inherited
# PATH, the store dirs for jq/git/coreutils are baked into that same line, so the
# plugin resolves its own dependencies on both hosts.
#
# The `id` in herdr-plugin.toml is the literal string "persiyanov.reviewr" (not
# derived from the GitHub owner), so linking from the store registers the same id
# an imperative `herdr plugin install` would — and keeps the same config dir,
# ~/.config/herdr/plugins/config/persiyanov.reviewr/.
{
  lib,
  rustPlatform,
  src,
  bash,
  jq,
  git,
  coreutils,
}:
rustPlatform.buildRustPackage {
  pname = "herdr-reviewr";
  # Tracks `version` in herdr-plugin.toml / Cargo.toml, which upstream keeps
  # equal to the release tag pinned in flake.nix.
  version = "0.29.0";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  # Pure-Rust dependency tree by design: syntect runs with `regex-fancy` and
  # `dump-load` rather than onig or yaml-load, so there's no native library or
  # openssl to thread through here.
  nativeBuildInputs = [ bash ];

  postPatch = ''
    substituteInPlace herdr/pane.sh \
      --replace-fail \
        'export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:''${PATH:-}"' \
        'export PATH="${
          lib.makeBinPath [
            jq
            git
            coreutils
          ]
        }:''${PATH:-}"'
  '';

  postInstall = ''
    cp herdr-plugin.toml $out/
    cp -r herdr $out/
    # install.sh is the release-download build hook: unreachable through
    # `plugin link`, and misleading to ship next to a from-source build.
    rm $out/herdr/install.sh
    chmod +x $out/herdr/*.sh
  '';

  # tests/pane_actions.rs drives herdr/pane.sh against the build directory, and
  # pane.sh refuses to open outside a git repo ("not a git repo: /build/source").
  # The unpacked source is a plain directory, so `git init` it — no commit needed,
  # `rev-parse --show-toplevel` succeeds on an empty repo. The identity and
  # default-branch settings keep git from erroring on a bare builder HOME.
  preCheck = ''
    export HOME=$TMPDIR
    git config --global user.email nobody@example.com
    git config --global user.name nobody
    git config --global init.defaultBranch main
    git init -q .
  '';
  nativeCheckInputs = [ git ];

  meta = {
    description = "herdr plugin: review an agent's diff in a sidebar and send line comments back to its input";
    homepage = "https://github.com/persiyanov/herdr-reviewr";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "herdr-reviewr";
  };
}
