# yabai + skhd — the tiling alternative to modules/desktop/aerospace.nix.
#
# STATUS: VERIFIED LIVE on macOS 26.6 arm64, yabai 7.1.25, SIP ENABLED, on the
# built-in 1512x982 display. Measured, not inferred:
#
#   * TILING WORKS WITH SIP ON — two windows at 746px each, x=8 and x=758,
#     matching the configured 8px outer padding and 4px inner gap exactly.
#   * `space --focus` WORKS WITH SIP ON (the 7.1.19 claim). Switched 1 -> 2 -> 1.
#   * `window --space` WORKS WITH SIP ON (the 7.1.25 claim). Moved a window from
#     space 1 to space 2.
#   * THE EMPTY SLOT IS REAL, which is the entire reason this module exists. One
#     window: 752px centred, 380px empty either side. Two windows: 373 @ x=8 then
#     746 @ x=385, with a 381px EMPTY right quarter and is-floating=false on
#     both. Three windows: 373 | 743 | 371. Targets were 372 | 744 | 372; the
#     residue is the 4px gaps and rounding on the 0.3333/0.6667 ratios.
#   * IDEMPOTENT — three consecutive $mod+I presses gave byte-identical geometry.
#   * STACK LAYOUT works and cycles: all windows full-size at one origin
#     (1496x848 @ x=8), and stack-index walks 1 -> 2 -> 3 with the wrap fallback.
#
# STILL UNVERIFIED: every test ran on ONE display, because the ultrawide was
# undocked. All the multi-monitor bindings ($mod+U, the arrows, and their
# $modShift variants) are therefore untested, as is the 5120px arithmetic
# (a quarter there should be 1274px and a centre 2548px).
#
# ============================================================================
# VERIFY THIS FILE YOURSELF. DO NOT TRUST IT.
# ============================================================================
#
# Every claim above was written after being measured — and the first drafts of
# this module were ALSO written confidently, from the documentation, and were
# wrong three separate times. Each bug survived review and died the moment the
# thing was actually driven:
#
#   1. THE SPLIT-DIRECTION BUG. The three-window snap inferred tree shape from
#      window widths after `space --equalize`. Degenerate: bsp chooses split
#      direction from the container's ASPECT RATIO, so on a narrow display the
#      right-hand region came out taller than wide and STACKED, giving two
#      windows identical widths and no shape to read.
#   2. THE TOPOLOGY BUG. Its replacement asserted in a comment that "the
#      leftmost window is the root's first child in every arrangement". False:
#      for [(L,C),R] the leftmost window's parent is the INNER split, so both
#      ratio commands landed on the same split and the root was never set.
#   3. THE PADDING-PERSISTENCE BUG. `space --padding` is persistent space state
#      and the layout keys did not clear it, so after a snap $mod+W squeezed the
#      stack into a 752px strip and new windows piled up BELOW instead of beside.
#      This one was documented in this very file and still shipped broken.
#
# THE LESSON, and the reason for this section: the man page tells you WHICH
# COMMANDS EXIST and WHAT NEEDS SIP. It does not tell you HOW bsp BEHAVES. Every
# behavioural fact below had to be discovered by driving it:
#
#   * split direction follows container aspect ratio, not config;
#   * `window --ratio` reaches only a window's IMMEDIATE parent split, which is
#     why centred-master caps at three windows;
#   * `space --padding` persists until something overwrites it;
#   * `query --windows` keeps STALE entries for closed windows — filter on
#     has-ax-reference;
#   * apps enforce minimum sizes (Firefox: 500px) and a window that refuses its
#     frame can stall re-layout for the WHOLE space, not just itself;
#   * `stack.next` does NOT wrap, and `focus` needs a focused window to start
#     from.
#
# SO, BEFORE CHANGING ANYTHING HERE:
#
#   * READ THE CURRENT DOCS, not this file. Upstream MOVED — the GitHub account
#     renamed koekeishiya -> asmvik, so links to koekeishiya/yabai redirect and
#     the search API rejects the old name outright. Current sources:
#       https://github.com/asmvik/yabai
#       https://github.com/asmvik/yabai/wiki
#       curl -sL https://raw.githubusercontent.com/asmvik/yabai/master/doc/yabai.asciidoc
#       curl -sL https://raw.githubusercontent.com/asmvik/yabai/master/CHANGELOG.md
#     The CHANGELOG is the load-bearing one for the SIP question: what needs the
#     scripting addition has been MOVING, and in the right direction (7.1.19
#     brought `space --focus` back under SIP, 7.1.25 `window --space`). Re-read
#     it rather than trusting the audit in this header.
#   * THEN DRIVE IT. `yabai -m query --windows --space` and
#     `yabai -m query --spaces --space` are the ground truth, and
#     `split-type` / `split-child` / `stack-index` / `has-ax-reference` are the
#     fields that actually explain behaviour. Print geometry before and after
#     every command. A one-shot probe script that measures each claim in order
#     beats reasoning about the tree, and repeated presses are the cheap test
#     that catches non-idempotent layout code.
#   * REMEMBER skhd DOES NOT RELOAD ITSELF. If a keymap edit appears to do
#     nothing, the agent is probably still serving the config it parsed at boot.
#     That is fixed structurally below (see the mkForce on the skhd plist), but
#     it is the first thing to suspect when the file on disk is provably correct
#     and the keys are provably wrong.
#
# WHY THIS EXISTS. AeroSpace cannot express an empty slot. Two tiled columns
# always divide their whole container and there is no placeholder node, so
# "quarter | centred half | empty quarter" is unreachable in its model. The
# config worked around that by floating windows and setting their frames through
# the Accessibility API, which (a) put the layout behind every newly opened
# window, because a float is not a tiling sibling, and (b) crashed AeroSpace
# outright via upstream issue #1311, a focus-over-floating-windows crash open
# since April 2025. That workaround is gone; see aerospace.nix's header.
#
# yabai expresses the same layout with NO FLOATING AT ALL, using two primitives
# AeroSpace lacks:
#
#   space --padding abs:<t>:<b>:<l>:<r>   reserve screen edge — this is what an
#                                        "empty slot" actually is
#   window --ratio abs:<r>               set a real tiled split ratio
#
# Nothing here is behind the SIP line. Verified against yabai's man page
# (doc/yabai.asciidoc), which puts "System Integrity Protection must be
# partially disabled" on individual commands rather than globally: padding,
# ratio, balance, equalize, mirror, rotate, layout, grid, warp, swap,
# window --focus, window --display, `space --focus` (since 7.1.19, 2026-04-18)
# and `window --space` (since 7.1.25, 2026-05-08) are all SIP-enabled-safe. What
# does need SIP partially disabled: opacity/shadow/animation, raise/lower/
# sub-layer, --toggle sticky|pip, scratchpads, and space create/destroy/move/
# swap/display. None of it is load-bearing, so enableScriptingAddition stays
# false and SIP stays on.
#
# WHAT THIS COSTS versus AeroSpace, priced honestly:
#
#   * WORKSPACES BECOME NATIVE macOS SPACES. yabai does not emulate them by
#     parking windows off-screen; `space --focus 3` switches a real Space. So
#     the ten Spaces have to be CREATED BY HAND (space --create is on the far
#     side of the SIP line), there is no persistent-workspaces equivalent, and
#     macOS renumbers them if they are ever reordered in Mission Control.
#   * KEYBINDINGS MOVE TO skhd, a second daemon. AeroSpace owned its own
#     hotkeys; yabai has none, so skhd is not optional.
#   * Z-ORDER CONTROL (raise/lower) is unavailable. Irrelevant while nothing
#     floats, which is the entire point of this module.
#   * ACCESSIBILITY IS GRANTED PER PATH, and yabai is a plain binary in the Nix
#     store, so every version bump gives it a NEW path and the grant has to be
#     given again. AeroSpace avoids this only because the dialog targets
#     AeroSpace.app via the Nix Apps aliaser. Expect to re-grant on upgrades;
#     this is the single most annoying ongoing cost.
#   * "DISPLAYS HAVE SEPARATE SPACES" MUST BE ON, which is a system-wide macOS
#     behaviour change and needs a log out. This module sets it declaratively;
#     see system.defaults.spaces.spans-displays below for the polarity trap and
#     the fact that it does not roll back.
#
# THE ONLY BINDINGS THAT GENUINELY DO NOT PORT, having gone through the
# AeroSpace keymap one row at a time:
#
#   * $modShift+COMMA / PERIOD — move the whole workspace to the other monitor.
#     yabai's equivalent is `space --display`, which is on the far side of the
#     SIP line. There is no workaround short of moving every window one at a
#     time, so these two keys are simply absent. This is the one daily gesture
#     that is lost.
#   * $mod+SEMICOLON service mode, and its contents. skhd does support modes, so
#     the mechanism exists, but two of the four bindings inside have no yabai
#     analogue: there is no flatten-workspace-tree (only --balance/--equalize,
#     which reset ratios rather than removing nesting) and no
#     close-all-windows-but-current, because yabai cannot close windows at all.
#     A mode carrying two working keys out of four is worse than no mode, so it
#     is left out; join-with's nearest analogue is on $modShift+Return.
#   * $mod+Q closes a TAB rather than a window in some apps — see the binding.
#
# Everything else is a one-for-one port, INCLUDING $mod+Tab: SPACE_SEL accepts
# `recent`, so workspace-back-and-forth needs no script.
#
# THE MAINTENANCE BET, recorded so it is not rediscovered: yabai is one
# maintainer (the GitHub account renamed koekeishiya -> asmvik, same person) who
# asked publicly in Oct 2025 whether anyone still used the project, then shipped
# nine releases between Jan and May 2026 — including a deliberate run at making
# things work with SIP enabled, which is exactly the path this module takes.
# Tahoe support is self-described as "preliminary" (7.1.16). macOS 27 lands late
# 2026 and every macOS major has historically broken something in yabai. Against
# that, AeroSpace is pushed to more often but left #1311 open for sixteen months
# while it crashed this machine.
#
# KEY TIERS ARE UNCHANGED from aerospace.nix, so muscle memory transfers:
#
#   cmd + alt + ctrl           -> $mod        select / focus
#   cmd + alt + ctrl + shift   -> $mod SHIFT  move
#
# That is the same physical key the Voyager expands to ⌃⌥⌘ (see the KEY TIERS
# note in aerospace.nix for the EventViewer verification), and the same gesture
# the retired skhdrc in modules/apps/desktop-mac.nix called `cmd + alt + ctrl`.
#
# PUNCTUATION IS GIVEN AS HEX VIRTUAL KEYCODES, not literal characters. skhd's
# grammar is `mod - key : command`, so a literal `-` as the key collides with
# the separator. 0x1B minus, 0x18 equal, 0x2C slash, 0x29 semicolon,
# 0x2B comma, 0x2F period.
#
# THE RUNBOOK — bringing this up from scratch. Nothing here happens
# automatically, and steps 2, 3 and 4 are each individually capable of making a
# working install look completely broken.
#
#   1. Switch the host over: in modules/hosts/mac-work/default.nix set
#      `windowManager = "yabai";`, then `rebuildhm`. That imports this module
#      INSTEAD of darwin.aerospace — never both, or two window managers fight
#      over every window.
#   2. GRANT PERMISSIONS TO BOTH BINARIES, by hand, in System Settings ->
#      Privacy & Security. yabai needs Accessibility; skhd installs an event tap
#      and needs its own grant (Accessibility, and Input Monitoring if keys still
#      do not fire). Point the dialog at the store paths:
#        readlink -f "$(which yabai)"
#        readlink -f "$(which skhd)"
#      UNTIL THIS IS DONE THERE IS NO TILING AND NO HOTKEYS AT ALL. Budget ten
#      minutes and do not start this mid-meeting. Note also that the grant is
#      keyed to the PATH, so a version bump invalidates it — see the cost list
#      above.
#   3. LOG OUT AND BACK IN. This module sets
#      system.defaults.spaces.spans-displays = false ("Displays have separate
#      Spaces"), which yabai REQUIRES — it aborts on startup otherwise — and the
#      window server only reads it at session start.
#
#      THIS IS THE MOST CONFUSING FAILURE IN THE WHOLE SETUP, because there is no
#      log. The nix-darwin plist sets no StandardErrorPath, so yabai's reason for
#      dying goes nowhere and all you see is an agent stuck at
#      `spawn scheduled` with a rising `runs` count, no yabai process, and
#      `failed to connect to socket..` from every command. To see the real
#      message, run it in the foreground:
#
#        launchctl bootout gui/$(id -u)/org.nixos.yabai
#        yabai -c "$(python3 -c 'import plistlib,os;print(plistlib.load(open(os.path.expanduser("~/Library/LaunchAgents/org.nixos.yabai.plist"),"rb"))["ProgramArguments"][2])')"
#
#      which prints, in one line:
#        yabai: 'display has separate spaces' is disabled! abort..
#
#      Adding StandardErrorPath to the agent would be a real improvement if this
#      setup sticks.
#   4. CREATE THE SPACES BY HAND in Mission Control — ten of them if you want the
#      full $mod+1..0 range. `space --create` is on the far side of the SIP line,
#      so Nix cannot do it and neither can yabai. Note SPACE_SEL takes a MISSION
#      CONTROL INDEX, numbered across ALL displays rather than per display, so
#      check what you actually got:
#        yabai -m query --spaces | jq '.[] | {index, display}'
#   5. VERIFY, in this order — cheapest thing that would kill the idea first.
#      All of these passed on 2026-08-18; re-run them after any yabai upgrade
#      rather than assuming they still hold:
#        yabai -m query --displays                    # server answers at all
#        csrutil status                               # should still say enabled
#        yabai -m space --focus 2                     # 7.1.19 claim
#        yabai -m window --space 2                    # 7.1.25 claim
#        yabai -m space --padding abs:8:8:1200:1200   # the empty-slot primitive
#        yabai -m space --padding abs:8:8:8:8         # ... and put it back
#      If `space --focus` or `window --space` fail, STOP — the daily gestures are
#      gone and the rest is not worth pursuing.
#   6. THEN THE ACTUAL QUESTION. Open two windows, press $mod+I, and confirm a
#      quarter-width window on the left, a half-width window centred, and an
#      EMPTY right quarter, with nothing floating:
#        yabai -m query --windows --space \
#          | jq -r '.[] | "\(.app) w=\(.frame.w) x=\(.frame.x) float=\(."is-floating")"'
#      That single observation is what this whole module exists for. Then press
#      $mod+I twice more — non-idempotent layout code is the most common bug
#      class here and repeated presses are how you catch it.
#   7. ROLLING BACK. Set windowManager = "aerospace" and rebuild, but CLEAR THE
#      PADDING FIRST or the margins outlive the switch:
#        yabai -m space --padding abs:8:8:8:8
#      Two things do NOT roll back, because nix-darwin's system.defaults are
#      write-only: spans-displays stays enabled, and the macOS Ctrl+1..6 desktop
#      shortcuts stay disabled. Both are harmless under AeroSpace, and both are
#      restorable by hand — see their comments below.
#
# TROUBLESHOOTING, in the order these actually went wrong:
#
#   * KEYS DO THE OLD THING, config is provably right -> skhd is serving what it
#     parsed at boot. Structurally fixed below (mkForce on the plist), but
#     `skhd --reload` is the manual escape hatch.
#   * SOME KEYS WORK, OTHERS DO NOTHING -> suspect a stale skhd config rather
#     than the individual bindings; commands that did not change between builds
#     will keep working and mask it.
#   * A WINDOW WILL NOT SHRINK, and the whole space stops re-laying-out -> an app
#     minimum size. Check with `--toggle float` then `--resize abs:<w>:<h>` and
#     read the width back.
#   * NEW WINDOWS APPEAR BELOW INSTEAD OF BESIDE, or a stack is inset -> leftover
#     `space --padding` from a snap. `yabai -m space --padding abs:8:8:8:8`.
#   * skhd CRASH-LOOPING at a high `runs` count -> a stale /tmp/skhd_$USER.pid
#     from an orphaned instance. Kill the orphan, remove the pid file.
#   * A CLOSED WINDOW STILL COUNTS -> stale query entry; filter on
#     has-ax-reference.
{ ... }:
{
  flake.modules.darwin.yabai =
    { config, lib, pkgs, ... }:
    let
      # Same gap sizes as aerospace.nix and hyprland.nix, so the machines feel
      # the same. centerMaster does arithmetic with both, so changing one here
      # must not silently skew the column widths.
      gapInner = 4;
      gapOuter = 8;

      mod = "cmd + alt + ctrl";
      modShift = "cmd + alt + ctrl + shift";

      # THE CENTRED-MASTER SNAP, tiled, with nothing floating: the layout
      # hyprland.nix gets from `master` with orientation = center and
      # mfact = 0.45, and the layout aerospace.nix can only reach for three
      # windows.
      #
      # Like the AeroSpace version this does NOT self-maintain — yabai re-tiles
      # on open and close, so the key has to be pressed again. Unlike the
      # AeroSpace version, every window count is expressible and nothing floats.
      #
      # PADDING IS PERSISTENT SPACE STATE, which is the one trap in here. It is
      # not reset when the window count changes, so EVERY branch below sets all
      # four values explicitly rather than only the ones it cares about.
      # Otherwise snapping with one window (which reserves both outer quarters)
      # and then opening a second leaves the pair sharing the middle half.
      centerMaster = pkgs.writeShellApplication {
        name = "yabai-center-master";
        runtimeInputs = [
          pkgs.yabai
          pkgs.jq
        ];
        text = ''
          OUTER=${toString gapOuter}
          INNER=${toString gapInner}

          notify() {
            /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" \
              >/dev/null 2>&1 || true
          }

          # Fail loudly when the server is not answering. Without this the first
          # query below dies under errexit with nothing on screen and nothing in
          # a log — the same silent-dead-server failure aerospace.nix grew an
          # activation heal for, and just as confusing to diagnose.
          if ! yabai -m query --displays >/dev/null 2>&1; then
            notify "Centred master" \
              "yabai is not answering — check Accessibility and the launchd agent"
            exit 1
          fi

          # Tiled windows only. Two filters, both load-bearing:
          #
          #   is-floating == false      a float someone put there by hand with
          #                             $mod+F is not part of the layout
          #   has-ax-reference == true  yabai's window list KEEPS STALE ENTRIES.
          #
          # That second one was found the hard way. After a window was closed,
          # `query --windows` still listed it — app name lower-cased ("ghostty"
          # not "Ghostty"), empty title, is-visible false, has-ax-reference
          # false. It counted toward COUNT, which pushed a three-window space
          # into the four-window branch and left two real windows overlapping.
          # yabai's own man page names this property as the way to spot them:
          # "yabai window commands will NOT WORK for these windows ... identified
          # by looking at the has-ax-reference property."
          WINS=$(yabai -m query --windows --space \
                   | jq -c '[.[] | select(."is-floating" == false
                                          and ."has-ax-reference" == true)
                                 | {id, x: .frame.x, w: .frame.w}]
                            | sort_by(.x)')
          COUNT=$(printf '%s' "$WINS" | jq 'length')

          MON_W=$(yabai -m query --displays --display | jq -r '.frame.w | floor')
          if [ -z "$MON_W" ] || [ "$MON_W" -le 0 ]; then
            notify "Centred master" "Could not read the focused display width"
            exit 1
          fi

          # The width windows can actually occupy: monitor minus the two outer
          # paddings minus the inner gaps between columns. Matches the AVAIL in
          # aerospace.nix so the numbers are comparable — on the 5120 ultrawide
          # 5120 - 8 - 8 - 4 - 4 = 5096, giving sides of 1274 and a centre
          # of 2548.
          AVAIL=$((MON_W - 2 * OUTER - 2 * INNER))
          SIDE=$((AVAIL / 4))

          # Only ids are read back now: the three-window branch reads the tree
          # from split-type/split-child rather than measuring widths.
          nth_id() { printf '%s' "$WINS" | jq -r ".[$1].id"; }

          case "$COUNT" in
            0)
              notify "Centred master" "No tiled windows on this space"
              exit 0
              ;;

            # --- ONE WINDOW: centre it at the master width --------------------
            # Reserve a quarter on BOTH sides and the lone window is left with
            # AVAIL/2, centred, with no floating and no Accessibility write.
            # This is the case AeroSpace cannot do at all: `resize width` exits 2
            # and does nothing on a window with no siblings to absorb the delta.
            1)
              yabai -m space --padding "abs:$OUTER:$OUTER:$((OUTER + SIDE)):$((OUTER + SIDE))"
              yabai -m space --gap "abs:$INNER"
              exit 0
              ;;

            # --- TWO WINDOWS: quarter, centred half, EMPTY right quarter ------
            # Reserve the right quarter with padding, then split what is left
            # 1:2. The remaining width is 3*AVAIL/4, so the left child wants
            # 1/3 of it to land on AVAIL/4 and leave AVAIL/2 for the centre.
            #
            # THIS IS THE LAYOUT THE WHOLE MODULE EXISTS FOR. With two windows
            # AeroSpace has exactly one root split and no way to leave a quarter
            # empty, which is why the old config floated both windows here.
            2)
              yabai -m space --padding "abs:$OUTER:$OUTER:$OUTER:$((OUTER + SIDE))"
              yabai -m space --gap "abs:$INNER"
              # Both windows are children of the one root split, so the ratio
              # can be set from either; the westmost is used because `--ratio`
              # names the fraction given to the FIRST child.
              yabai -m window "$(nth_id 0)" --ratio abs:0.3333 || {
                notify "Centred master" "Could not set the split ratio"
                exit 1
              }
              exit 0
              ;;

            # --- THREE WINDOWS: 1/4 | 1/2 | 1/4, all tiled -------------------
            # No padding beyond the base, so the tree fills the screen and the
            # ratios do all the work.
            #
            # bsp IS A TREE, and `--ratio` only reaches a window's IMMEDIATE
            # parent split. Three windows are always one leaf beside a nested
            # pair, so getting 25/50/25 means setting two ratios on two
            # different splits — and both splits must be VERTICAL (side-by-side)
            # for widths to mean anything.
            #
            # THE BUG THIS BRANCH WAS WRITTEN AROUND, found by running it: bsp
            # picks a split direction from the container's ASPECT RATIO, not
            # from anything configurable. On the built-in 1512x982 display the
            # right-hand region is 746 wide by 848 tall — taller than wide — so
            # opening a third window there split it HORIZONTALLY and produced two
            # windows stacked at identical x and width. Measured live:
            #
            #   id=75  x=8    w=373   split-type=vertical    first_child
            #   id=202 x=385  w=1119  split-type=horizontal  first_child
            #   id=212 x=385  w=1119  split-type=horizontal  second_child
            #
            # An earlier version of this branch tried to infer the shape from
            # widths after `space --equalize`. That cannot work: a stacked pair
            # has the same width as its parent, so the measurement is degenerate
            # and the ratios then land on the wrong splits.
            #
            # `split-type` AND `split-child` ARE THE ANSWER, and they were there
            # all along in `query --windows`: split-type is the orientation of a
            # window's PARENT split, split-child is which side of it the window
            # sits on. So the shape can be read directly instead of guessed, and
            # `window --toggle split` flips a split that came out horizontal.
            # Verified live — one toggle turned the stack above into
            # 373 | 743 | 371, all tiled, nothing floating.
            3)
              yabai -m space --padding "abs:$OUTER:$OUTER:$OUTER:$OUTER"
              yabai -m space --gap "abs:$INNER"

              # Sorted by x THEN y, so a stacked pair still reads in visual
              # order rather than in whatever order the query returned.
              read_tree() {
                yabai -m query --windows --space \
                  | jq -c '[.[] | select(."is-floating" == false
                                         and ."has-ax-reference" == true)
                                | {id, x: .frame.x, y: .frame.y,
                                   split: ."split-type"}]
                           | sort_by(.x, .y)'
              }
              tid() { printf '%s' "$1" | jq -r ".[$2].id"; }

              # STEP 1 — CONSTRUCT the shape instead of deducing it. Re-inserting
              # the rightmost window so it splits the middle one forces
              # [L,(C,R)]: the warped pair gets a common parent and L is left as
              # the root's other child. Verified live from a [(L,C),R] start —
              # afterwards the two right-hand windows reported a shared parent
              # split and L reported the root's.
              #
              # This replaces two earlier attempts that both asserted tree
              # properties without checking them, and both produced wrong
              # geometry:
              #   * measuring widths after `space --equalize` — degenerate,
              #     because a stacked pair is exactly as wide as its parent;
              #   * assuming "the leftmost window is the root's first child",
              #     which is false for [(L,C),R] — there the leftmost window's
              #     parent is the INNER split, so both ratio commands landed on
              #     the same split and the root was never set.
              T=$(read_tree)
              yabai -m window "$(tid "$T" 2)" --warp "$(tid "$T" 1)" \
                >/dev/null 2>&1 || true

              # STEP 2 — FORCE BOTH SPLITS SIDE-BY-SIDE. bsp picks a split
              # direction from the container's ASPECT RATIO, not from anything
              # configurable, so on a narrow display the right-hand region comes
              # out taller than wide and gets split into a STACK. Measured: two
              # windows at identical x and width.
              #
              # split-type reports a window's PARENT split, so any window
              # reporting "horizontal" names a split that needs flipping. The
              # loop re-reads because each toggle reshapes the tree; three passes
              # is comfortably more than the two splits three windows can have.
              for _ in 1 2 3; do
                T=$(read_tree)
                H=$(printf '%s' "$T" \
                      | jq -r 'map(select(.split == "horizontal"))[0].id // empty')
                [ -n "$H" ] || break
                yabai -m window "$H" --toggle split >/dev/null 2>&1 || true
              done

              # STEP 3 — RATIOS. Both splits are vertical and the shape is known,
              # so this is just arithmetic: the root gives its first child a
              # quarter, and the pair splits the remaining three quarters 2:1 to
              # put AVAIL/2 in the middle.
              T=$(read_tree)
              yabai -m window "$(tid "$T" 0)" --ratio abs:0.25 >/dev/null 2>&1 || true
              yabai -m window "$(tid "$T" 1)" --ratio abs:0.6667 >/dev/null 2>&1 || true

              # A WINDOW WITH A MINIMUM SIZE CAN DEFEAT ALL OF THIS, and it takes
              # the rest of the space down with it. Firefox measured a hard floor
              # of 500px wide here: asked for 450, 400, 372, 300 and 200 it
              # returned 500 every time. A quarter of this 1512px display is
              # 372px, so Firefox cannot BE a side column, and when it refuses
              # the frame yabai hands it the whole space is left inconsistent —
              # the OTHER windows also stopped re-laying-out until Firefox was
              # moved off the space, after which `--balance` worked instantly.
              #
              # Not worked around here, because the honest fix is either a wider
              # display (a quarter of the 5120 ultrawide is 1274px, comfortably
              # over the floor) or keeping such a window in the CENTRE slot,
              # which at AVAIL/2 = 744px clears it. Report it rather than
              # silently producing a broken layout.
              AFTER=$(read_tree)
              NARROW=$(printf '%s' "$AFTER" | jq -r 'length')
              if [ "$NARROW" = "3" ]; then
                W_L=$(yabai -m query --windows --window "$(tid "$AFTER" 0)" \
                        | jq -r '.frame.w | floor')
                if [ "$W_L" -gt "$((SIDE + SIDE / 2))" ]; then
                  notify "Centred master" \
                    "Left window will not go below ''${W_L}px (minimum size) — layout is approximate"
                fi
              fi
              exit 0
              ;;

            # More than three: base padding and equal columns is the honest
            # answer. There is no centre to widen once the row is this long.
            *)
              yabai -m space --padding "abs:$OUTER:$OUTER:$OUTER:$OUTER"
              yabai -m space --gap "abs:$INNER"
              yabai -m space --balance
              notify "Centred master" "$COUNT tiled windows — balanced instead"
              exit 0
              ;;
          esac
        '';
      };

      # DIRECTIONAL FOCUS THAT ALSO WORKS IN A STACK, for $mod+H/J/K/L.
      #
      # THE PROBLEM: a stacked space has no geometry to navigate. Every window
      # sits full-screen at the same origin — measured, three windows all
      # 1496x848 at x=8 — so `window --focus south` has nothing to find and the
      # directional keys silently do nothing. The only route between stacked
      # windows is `--focus stack.next|stack.prev`, which is a different command
      # rather than a different argument, so it cannot be expressed as one static
      # binding.
      #
      # Hence this: read the space's layout and dispatch. In bsp it is exactly
      # `window --focus <dir>`; in a stack, north/west page backwards and
      # south/east page forwards. All four keys are wired rather than just J/K so
      # that whichever axis you reach for works — there is only one axis in a
      # stack, and a key that does nothing is worse than a key that does the
      # obvious thing.
      #
      # THE WRAP MATTERS. Measured: stack.next walks 1 -> 2 -> 3 and then fails
      # with "could not locate the next stacked window", stranding you at the end
      # of the stack. The fallback to stack.first / stack.last cycles instead —
      # verified 1->2->3->1 forward and 3->2->1->3 backward. Same reason the
      # display bindings need it: yabai's `next` selectors fail at the edge where
      # AeroSpace had an explicit --wrap-around flag.
      focusDir = pkgs.writeShellApplication {
        name = "yabai-focus-dir";
        runtimeInputs = [
          pkgs.yabai
          pkgs.jq
        ];
        text = ''
          DIR="$1"
          TYPE=$(yabai -m query --spaces --space | jq -r '.type')

          if [ "$TYPE" = "stack" ]; then
            case "$DIR" in
              north | west)
                yabai -m window --focus stack.prev 2>/dev/null \
                  || yabai -m window --focus stack.last 2>/dev/null || true
                ;;
              south | east)
                yabai -m window --focus stack.next 2>/dev/null \
                  || yabai -m window --focus stack.first 2>/dev/null || true
                ;;
            esac
          else
            # Fails at the edge of the layout, which is correct and should not
            # be reported as an error from a keypress.
            yabai -m window --focus "$DIR" 2>/dev/null || true
          fi
        '';
      };

      # RESET THE SPACE'S PADDING, then apply a layout. Every layout key goes
      # through this, and it exists because of a genuinely nasty trap.
      #
      # `space --padding` IS PERSISTENT SPACE STATE. The centred-master snap uses
      # it to reserve the empty quarters — that is the whole trick that lets an
      # empty slot exist without floating anything — but nothing clears it
      # afterwards. So after a one-window snap the space carries
      # padding 8:8:380:380, and then:
      #
      #   * $mod+W squeezed the STACK into the leftover 752px middle strip
      #     instead of going full width;
      #   * every newly opened window split that 752x848 region, and because it
      #     is taller than wide bsp split it HORIZONTALLY, so new windows piled
      #     up BELOW rather than beside.
      #
      # Both observed live, and both read as the window manager being broken when
      # in fact the layout was doing exactly what the stale padding asked for.
      # Resetting padding is therefore part of "switch layout", not a separate
      # step to remember.
      #
      # $mod+I is the one key that deliberately SETS padding again afterwards —
      # see centerMaster, where each branch writes all four values explicitly.
      setLayout = name: layout: pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [ pkgs.yabai ];
        text = ''
          yabai -m space --padding abs:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}
          yabai -m space --gap abs:${toString gapInner}
          ${layout}
        '';
      };

      toStack = setLayout "yabai-to-stack" "yabai -m space --layout stack";
      toBsp = setLayout "yabai-to-bsp" "yabai -m space --layout bsp";

      # bsp <-> stack as a genuine toggle, for $mod+Y. `space --layout` has no
      # toggle form, so the current layout is read back and inverted.
      layoutToggle = pkgs.writeShellApplication {
        name = "yabai-layout-toggle";
        runtimeInputs = [
          pkgs.yabai
          pkgs.jq
        ];
        text = ''
          yabai -m space --padding abs:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}
          yabai -m space --gap abs:${toString gapInner}
          CUR=$(yabai -m query --spaces --space | jq -r '.type')
          if [ "$CUR" = "bsp" ]; then
            yabai -m space --layout stack
          else
            yabai -m space --layout bsp
          fi
        '';
      };

      # A new Firefox WINDOW, for $mod+B. Identical mechanism to the AeroSpace
      # module's newWindow and for the same reasons — `open -b` only ACTIVATES a
      # running Firefox, `--args --new-window` is dropped when the app is already
      # up, and `open -n` starts a rival instance that fights over the profile
      # lock — so the binary is run directly and Firefox's own remote protocol
      # hands the request to the running instance.
      #
      # WHAT IS NOT PORTED: the workspace carry. The AeroSpace version had to
      # read the focused workspace before launching and move the new window
      # back, because activating an app raises its most recently used window and
      # AeroSpace followed that focus onto another workspace. Under yabai a
      # Space switch is a real Space switch, so whether the same teleport
      # happens is UNVERIFIED. If $mod+B starts dumping you on another Space,
      # port new_window_here from aerospace.nix — the logic transfers, with
      # `yabai -m query --spaces --space | jq -r .index` for the read and
      # `yabai -m window <id> --space <n>` for the carry.
      #
      # The path comes from LaunchServices via the bundle id rather than being
      # hardcoded, because Firefox is hand-installed in /Applications and
      # nothing in this repo manages its filename.
      newWindow = pkgs.writeShellApplication {
        name = "firefox-new-window-yabai";
        text = ''
          APP=$(/usr/bin/osascript -e \
            'POSIX path of (path to application id "org.mozilla.firefox")')
          "$APP/Contents/MacOS/firefox" --new-window about:newtab
        '';
      };

      # HJKL, keeping the Hyprland spatial arrangement. yabai's directions are
      # compass points rather than left/down/up/right.
      directions = {
        h = "west";
        j = "south";
        k = "north";
        l = "east";
      };

      # 1..9 are Spaces of the same index; the 0 key takes Space 10, exactly as
      # $mod+0 does in hyprland.nix and aerospace.nix.
      workspaces = (map (n: {
        key = toString n;
        index = toString n;
      }) (lib.range 1 9))
      ++ [
        {
          key = "0";
          index = "10";
        }
      ];

      # skhd's config is one flat string, so the keymap is assembled as lines
      # rather than an attrset. `mod - key : command`.
      bind = m: k: cmd: "${m} - ${k} : ${cmd}";

      keymap = lib.concatStringsSep "\n" (
        [
          "# --- Directional focus and move -----------------------------------"
        ]
        ++ lib.mapAttrsToList (
          k: d: bind mod k "${lib.getExe focusDir} ${d}"
        ) directions
        # --warp re-inserts the window splitting its neighbour, which is the
        # move that matches AeroSpace's `move` on a tree. --swap would exchange
        # two windows in place instead, never reshaping the tree, so a window
        # could not be moved into a different column.
        ++ lib.mapAttrsToList (k: d: bind modShift k "yabai -m window --warp ${d}") directions

        ++ [
          ""
          "# --- Workspaces (REAL macOS Spaces — create all ten by hand) -------"
          # SPACE_SEL takes a MISSION CONTROL INDEX, which is numbered across
          # every display rather than per display. So on this two-display setup
          # the ultrawide's Spaces are not necessarily 1..10 — if the built-in
          # display owns Spaces, they take indices in the same sequence. Check
          # with `yabai -m query --spaces | jq '.[] | {index, display}'` before
          # assuming these ten keys land where they read.
        ]
        ++ map (w: bind mod w.key "yabai -m space --focus ${w.index}") workspaces
        # `--space ^<n>` follows the window to its new Space, matching
        # AeroSpace's move-node-to-workspace, which focuses the target.
        ++ map (w: bind modShift w.key "yabai -m window --space ^${w.index}") workspaces

        ++ [
          ""
          "# --- Monitors ------------------------------------------------------"
          # U toggles the focused display and $modShift+U throws the window
          # there, the same primary gesture as aerospace.nix. `next` does not
          # wrap in yabai the way AeroSpace's --wrap-around does, so these fall
          # back to display 1 at the end of the list; with two displays that is
          # exactly a toggle.
          (bind mod "u" "yabai -m display --focus next || yabai -m display --focus first")
          (bind modShift "u" "yabai -m window --display next --focus || yabai -m window --display first --focus")

          # Explicit directions on the arrows, for when the target matters
          # rather than just "the other one". The physical arrangement here is
          # VERTICAL — the Dell U4924DW above, the built-in below — so
          # down = laptop and up = ultrawide. No wrap, deliberately: a
          # directional key should fail at the edge.
          (bind mod "left" "yabai -m display --focus west")
          (bind mod "down" "yabai -m display --focus south")
          (bind mod "up" "yabai -m display --focus north")
          (bind mod "right" "yabai -m display --focus east")
          (bind modShift "left" "yabai -m window --display west --focus")
          (bind modShift "down" "yabai -m window --display south --focus")
          (bind modShift "up" "yabai -m window --display north --focus")
          (bind modShift "right" "yabai -m window --display east --focus")

          ""
          "# --- Layout --------------------------------------------------------"
          # The centred-master snap. On I for the same reason aerospace.nix puts
          # it there: the deleted rectangle.nix used U/I/O for this row and I
          # was its centreHalf.
          (bind mod "i" (lib.getExe centerMaster))

          # Flip the orientation of the split the focused window sits in —
          # hy3's implicit behaviour when you split against the grain, and
          # AeroSpace's $mod+/ (layout horizontal vertical).
          (bind mod "0x2C" "yabai -m window --toggle split")

          # bsp <-> stack, the "switch the whole layout" gesture that
          # aerospace.nix puts on $mod+Y as tiles<->accordion. yabai's stack is
          # the nearest thing to an accordion or an hy3 tab group.
          #
          # A REAL TOGGLE, via the script below. `space --layout` only SETS a
          # layout, so writing this as `--layout bsp` would have made $mod+Y and
          # $modShift+W two bindings for one command — the keymap rot that
          # aerospace.nix explicitly warns about, and the reason the
          # focus-monitor pair on comma/period was deleted there.
          (bind mod "y" (lib.getExe layoutToggle))
          (bind mod "w" (lib.getExe toStack))
          (bind modShift "w" (lib.getExe toBsp))

          # CYCLE WITHIN A STACK, on comma/period. Without these, stack mode is a
          # trap: every window sits full-screen at the same origin (measured:
          # three windows all 1496x848 at x=8) and the directional focus keys
          # have no geometry to work with, so there is no way to page through.
          # `window --focus stack.next|stack.prev` is the only route, and it was
          # verified live — stack-index 1 -> 2.
          #
          # Comma and period were freed by $modShift+COMMA/PERIOD not porting
          # (move-workspace-to-monitor needs SIP off), and they read as "previous
          # / next" the way a tab bar would.
          # NO DEDICATED STACK-CYCLING KEYS. They lived on comma/period for one
          # revision, then became redundant: $mod+H/J/K/L now page through a
          # stack via focusDir above, which is the same motion as moving between
          # tiled windows. Two bindings for one action is how a keymap rots.

          # Reset the tree — the closest thing to "undo my layout". Also the way
          # back from a snap, since it clears the ratios but NOT the padding;
          # $mod+I with the new window count is the full reset.
          (bind modShift "0x2C" "yabai -m space --balance")

          ""
          "# --- Window state --------------------------------------------------"
          # $mod+F toggles float, matching aerospace.nix exactly. This is the
          # ONLY float anywhere in this module, and it is entirely manual — the
          # snap never floats anything, which is the whole point.
          #
          # The retired skhdrc paired this with `--grid 4:4:1:1:2:2` to centre
          # the window at half size. NOT ported: it is only correct starting
          # from the tiled state, because on an already-floating window the
          # toggle re-tiles first and --grid then fails on a managed window. A
          # second binding that is a broken variant of the first is how a keymap
          # rots.
          (bind mod "f" "yabai -m window --toggle float")
          # yabai's own zoom, not macOS native fullscreen: zoom-fullscreen keeps
          # the window inside yabai's tree, so it can be un-zoomed and still
          # tiles. native-fullscreen would create a real Space yabai cannot
          # manage without the scripting addition.
          (bind modShift "f" "yabai -m window --toggle zoom-fullscreen")
          # yabai has no close command — it manages windows, it does not own
          # them — so this is the standard macOS close chord sent onward.
          # AeroSpace's $mod+Q had a real `close`; this is the nearest thing.
          # NOT A FAITHFUL PORT, and the difference is worth knowing before
          # pressing it. AeroSpace's `close` performs the window's AX close
          # action, so it closes the WINDOW. yabai has no close command at all —
          # it manages windows, it does not own them — so this synthesises the
          # macOS convention instead, and ⌘W is per-app: in Firefox it closes the
          # current TAB, not the window (⌘⇧W is Firefox's close-window). Less
          # destructive than the AeroSpace behaviour rather than more, so it is
          # left as the safe default; swap to `cmd + shift - w` if the
          # window-close semantics matter more than cross-app consistency.
          (bind mod "q" "skhd -k 'cmd - w'")

          # DO NOT USE `yabai --restart-service` HERE. That flag drives yabai's
          # OWN launchd service file, ~/Library/LaunchAgents/com.asmvik.yabai
          # .plist, which this config does not use — nix-darwin installs the
          # agent as org.nixos.yabai. So --restart-service would not restart the
          # running instance; at best it fails, at worst it installs and starts
          # a SECOND yabai from yabai's own plist, and the two then fight over
          # every window. Address the nix-darwin agent directly.
          (bind modShift "r" "launchctl kickstart -k gui/$(id -u)/org.nixos.yabai")

          # $mod SHIFT Return is hy3:makegroup v. yabai's --insert sets which
          # way the NEXT window splits this one, which is the closest analogue:
          # AeroSpace's join-with pulls two windows under a shared parent, and
          # this decides where that parent's split will fall.
          (bind modShift "return" "yabai -m window --insert south")

          ""
          "# --- Resize --------------------------------------------------------"
          # Absolute point deltas on the east handle, matching the ±50 that
          # aerospace.nix uses for `resize smart`.
          (bind mod "0x1B" "yabai -m window --resize right:-50:0")
          (bind mod "0x18" "yabai -m window --resize right:50:0")

          ""
          "# --- Launchers -----------------------------------------------------"
          # $mod Return -> ghostty and $mod B / $mod A -> browser, mirroring
          # both hyprland.nix and aerospace.nix. -n forces a new instance rather
          # than raising the existing one; -a takes the app name because
          # ghostty-bin is aliased into /Applications/Nix Apps by the host.
          (bind mod "return" "open -na Ghostty")
          (bind mod "b" (lib.getExe newWindow))
          (bind mod "a" "open -b org.mozilla.firefox https://claude.ai")
          # $modShift+B, the Firefox "Work" container launcher, is DELIBERATELY
          # NOT PORTED from aerospace.nix. It never actually worked: the
          # container has to come from Multi-Account Containers reassigning an
          # assigned site, and that assignment was never set up. aerospace.nix's
          # workContainer documents every route that was tried and failed —
          # worth reading before anyone tries again, but not worth carrying
          # a second copy of a launcher that does nothing.

          ""
          "# --- Misc ----------------------------------------------------------"
          # workspace-back-and-forth. SPACE_SEL includes `recent`, so this is a
          # one-for-one port of AeroSpace's $mod+Tab and needs no state file of
          # its own. (An earlier revision of this header claimed there was no
          # yabai equivalent. There is; that claim was wrong.)
          (bind mod "tab" "yabai -m space --focus recent")
          ""
        ]
      );
    in
    {
      # SIP STAYS ON. enableScriptingAddition would need `csrutil disable` from
      # recovery, and nothing this module uses is on the far side of that line —
      # see the header for the audited command list. It is stated explicitly
      # rather than left to the default so that turning it on is a deliberate,
      # reviewable act.
      services.yabai = {
        enable = true;
        enableScriptingAddition = false;

        config = {
          layout = "bsp";

          # Gaps, matching aerospace.nix and hyprland.nix. centerMaster
          # overwrites the space-level padding as part of snapping, so these are
          # the values it returns to for three or more windows.
          top_padding = gapOuter;
          bottom_padding = gapOuter;
          left_padding = gapOuter;
          right_padding = gapOuter;
          window_gap = gapInner;

          # Off, matching aerospace.nix's focus-follows-mouse.enabled = false.
          # The retired yabai config carried both `off` and, later,
          # `autoraise` — the mac history is genuinely contradictory about
          # wanting this. Flip to "autoraise" for Hyprland parity, which sets
          # input.follow_mouse = 1.
          focus_follows_mouse = "off";
          # The surviving half of the retired config's `mouse_follows_focus on`,
          # and the analogue of aerospace.nix's
          # on-focused-monitor-changed = move-mouse monitor-lazy-center.
          mouse_follows_focus = "on";

          # New windows become the second child, so they open to the right of
          # or below the window they split rather than displacing it. Same value
          # the retired config used.
          window_placement = "second_child";
          split_ratio = 0.5;
          # OFF, and this matters more here than it looks: auto_balance would
          # re-equalise every ratio whenever a window opens or closes, which
          # would undo a snap immediately rather than merely failing to maintain
          # it. The snap is already documented as not self-maintaining; this
          # keeps it from being actively destroyed.
          auto_balance = "off";

          # fn as the drag modifier keeps the mouse bindings off the four-
          # modifier tiers above. aerospace.nix has no equivalent — AeroSpace
          # offers no mouse-drag resize at all — so this is a small gain.
          mouse_modifier = "fn";
          mouse_action1 = "move";
          mouse_action2 = "resize";
          mouse_drop_action = "swap";

          # Everything below here needs the scripting addition and is therefore
          # left at its inert value ON PURPOSE. Do not "fix" these by enabling
          # window_shadow or the opacity settings: with SIP enabled yabai either
          # ignores them or errors, and they buy nothing but eye candy.
          window_shadow = "on";
          window_opacity = "off";
        };
      };

      # A HARD REQUIREMENT, not a preference. yabai refuses to start at all
      # without it, and says so on stderr before exiting:
      #
      #   yabai: 'display has separate spaces' is disabled! abort..
      #
      # With no StandardErrorPath in the launchd plist that message goes
      # nowhere, so the only symptom is an agent stuck at `spawn scheduled` with
      # a rising `runs` count, no yabai process, and `failed to connect to
      # socket..` from every command. That is how this presented on first boot
      # here; if yabai ever appears to be "installed but dead", check this first.
      #
      # THE POLARITY IS INVERTED relative to the UI. This key is "one space
      # SPANS all displays", so false is what gives each display its own
      # Spaces — System Settings -> Desktop & Dock -> Mission Control ->
      # "Displays have separate Spaces" CHECKED.
      #
      # IT NEEDS A LOG OUT AND BACK IN. Neither the rebuild nor restarting the
      # agent is enough; the window server reads this at session start.
      #
      # AND IT DOES NOT ROLL BACK. nix-darwin's system.defaults are write-only —
      # the same trap the retired mac-spaces module left behind, documented in
      # aerospace.nix's header. Removing this module will NOT restore the old
      # value. To undo by hand:
      #   defaults write com.apple.spaces spans-displays -bool true
      # and log out again. AeroSpace does not care either way (it never touches
      # Mission Control), so leaving it enabled after switching back is harmless
      # apart from changing how the displays behave in Mission Control itself.
      system.defaults.spaces.spans-displays = false;

      # yabai has no hotkeys of its own, so this is not optional the way it
      # would be alongside AeroSpace.
      services.skhd = {
        enable = true;
        skhdConfig = keymap;
      };

      # MAKE THE skhd AGENT'S PLIST DEPEND ON THE KEYMAP, which is the whole fix
      # for "the config is correct but the keys do the old thing".
      #
      # skhd parses its config ONCE, at startup. nix-darwin reloads a launchd
      # agent when that agent's PLIST changes — so whether a config edit reaches
      # the running process depends entirely on whether the plist mentions the
      # config by a path that changes. The two upstream modules disagree:
      #
      #   yabai:  -c /nix/store/<hash>-yabairc   store path -> plist changes ->
      #                                          agent reloaded -> edit lands
      #   skhd:   -c /etc/skhdrc                 stable path -> plist NEVER
      #                                          changes -> agent never touched
      #
      # So yabai tracked edits and skhd silently did not. Observed here hours
      # after a rebuild: `readlink -f /etc/skhdrc` matched the built store path
      # exactly, while $mod+I still ran a previous, buggy build of the
      # centred-master script and $mod+H/J/K/L still used the pre-focusDir
      # static bindings that cannot page a stack. A config that is provably
      # correct on disk and wrong in practice is about the worst failure mode to
      # debug, which is why this is worth fixing structurally rather than by
      # remembering to reload.
      #
      # Pointing -c at a store path adopts yabai's behaviour, using nix-darwin's
      # own reload rather than a bespoke activation step. mkForce because the
      # upstream module already defines ProgramArguments. services.skhd stays
      # enabled so /etc/skhdrc is still written — it costs nothing, it is the
      # obvious place to look when inspecting the live keymap, and leaving
      # skhdConfig empty would drop the -c flag entirely and let skhd fall back
      # to ~/.config/skhd/skhdrc.
      launchd.user.agents.skhd.serviceConfig.ProgramArguments = lib.mkForce [
        "${config.services.skhd.package}/bin/skhd"
        "-c"
        "${pkgs.writeText "skhdrc" keymap}"
      ];

      # DISABLE macOS'S OWN Ctrl+1..6 DESKTOP SWITCHING, so the meh key
      # (⌃⌥⌘ + 1..0, bound above to `space --focus`) is the only way to change
      # workspace.
      #
      # WHY THESE EXIST AT ALL: the retired darwin.macSpaces module bound them,
      # and nix-darwin's system.defaults are write-only — deleting that module
      # did NOT unwrite them. aerospace.nix's header records this and tells the
      # reader to clear them by hand in System Settings. Measured here before
      # touching anything: ids 118..123 were all `enabled = true` with modifier
      # 262144 (Ctrl) on keys 1..6, so they were still live years later. They did
      # not collide with AeroSpace, whose workspaces are not Spaces at all — but
      # under yabai they are a genuine second, unwanted route to the same action.
      #
      # THE IDS ARE MISSION CONTROL "Switch to Desktop N": 118 is Desktop 1
      # through 123 for Desktop 6. 124..127 were unset here, so Desktops 7..10
      # never had a shortcut and none is added.
      #
      # `-dict-add` IS LOAD-BEARING. It merges into AppleSymbolicHotKeys, leaving
      # every other system hotkey alone. Do NOT reach for
      # `defaults delete com.apple.symbolichotkeys AppleSymbolicHotKeys` or a
      # plain `defaults write` of the whole dict — either would wipe every system
      # hotkey, not just these six. aerospace.nix's header carries the same
      # warning; this is the safe form of the same operation.
      #
      # The full `value` dict is restated rather than writing `{enabled = 0;}`,
      # because -dict-add replaces the entry for that id wholesale; dropping
      # `value` would lose the key assignment and leave System Settings showing
      # the shortcut as unassigned rather than as unchecked.
      #
      # LIKE spans-displays ABOVE, THIS DOES NOT ROLL BACK. Switching back to
      # AeroSpace leaves Ctrl+1..6 disabled. To restore them, use System
      # Settings -> Keyboard -> Keyboard Shortcuts -> Mission Control (its
      # "Restore Defaults" is safe), which is also the sanctioned way to change
      # any of this by hand.
      #
      # activateSettings -u reloads the hotkey table in the running session, so
      # this takes effect on rebuild without waiting for a log out.
      system.activationScripts.postActivation.text =
        let
          user = config.system.primaryUser;
          # id, ASCII of the digit, virtual keycode. Note 5 and 6 are keycodes
          # 23 and 22 — NOT sequential, which is why these are listed out rather
          # than computed from the id.
          desktopHotkeys = [
            { id = 118; ascii = 49; code = 18; }
            { id = 119; ascii = 50; code = 19; }
            { id = 120; ascii = 51; code = 20; }
            { id = 121; ascii = 52; code = 21; }
            { id = 122; ascii = 53; code = 23; }
            { id = 123; ascii = 54; code = 22; }
          ];
          disable = h: ''
            sudo --user=${user} -- defaults write com.apple.symbolichotkeys \
              AppleSymbolicHotKeys -dict-add ${toString h.id} \
              '{enabled = 0; value = {parameters = (${toString h.ascii}, ${toString h.code}, 262144); type = standard;};}' \
              || true
          '';
        in
        ''
          echo "disabling macOS Ctrl+1..6 desktop switching..." >&2
          ${lib.concatMapStrings disable desktopHotkeys}
          sudo --user=${user} -- /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u \
            >/dev/null 2>&1 || true

          # NO EXPLICIT skhd RELOAD HERE, and deliberately — see the mkForce on
          # launchd.user.agents.skhd.serviceConfig.ProgramArguments below. Once
          # the plist references the keymap by store path, nix-darwin's own
          # activation does the reload:
          #
          #   if ! diff <new plist> <installed plist> &>/dev/null; then
          #     launchctl unload ...; cp -f ...; launchctl load -w ...
          #   fi
          #
          # (quoted from /run/current-system/activate). So the chain is
          # keymap edit -> new store path -> plist differs -> diff fails ->
          # unload/load -> skhd re-reads. A `skhd --reload` line lived here for
          # one revision and is now redundant; it was removed rather than kept
          # "just in case", because a belt-and-braces step that never fires is
          # indistinguishable from one that does not work.
        '';

      # yabai must be pickable in the Accessibility dialog, and the Nix Apps
      # aliaser only covers environment.systemPackages. Unlike AeroSpace — an
      # .app bundle that services.aerospace adds itself — yabai is a bare
      # binary, so the dialog has to be pointed at its store path by hand.
      # Listing it here at least puts a stable-ish `which yabai` on PATH to
      # resolve. See the ACCESSIBILITY cost in the header: the grant does not
      # survive a version bump.
      environment.systemPackages = [ pkgs.yabai ];
    };
}
