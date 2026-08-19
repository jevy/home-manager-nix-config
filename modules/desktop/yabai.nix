# yabai + skhd — the tiling alternative to modules/desktop/aerospace.nix.
#
# ============================================================================
# THE PLAN — a SELF-MAINTAINING centred master. Status per step; keep this
# block current as steps land or die.
# ============================================================================
#
# STEP 0 — MANUAL SNAP on $mod+I. DONE, VERIFIED LIVE on both displays (see
#   the STATUS block below). Its one structural flaw: it does not maintain
#   itself. yabai re-tiles on every open/close/move and the key had to be
#   pressed again by hand.
#
# STEP 1 — SIGNAL-DRIVEN AUTO-SNAP. LIVE, WORKING PER FIRST REPORT
#   (2026-08-18): layout self-maintains — but with LOTS OF FLASHING, most of
#   it pointless: the snap replayed the full tree surgery even when the
#   layout was already correct, and space_changed runs it on every space
#   switch. Hence STEP 1.1 below. yabai has a signal system (`yabai -m signal --add
#   event=<E> action=<CMD>`) — arbitrary commands on window-manager events,
#   none of it behind the SIP line — which this module previously never used.
#   Registered declaratively via services.yabai.extraConfig (the yabairc is a
#   store path in the launchd plist, so edits reload the same way the skhd
#   keymap does). The wiring, all in this file:
#
#     * centerMasterAuto — flock-serialised, notification-silent wrapper that
#       re-runs the snap ONLY when the focused space is already bsp, so a
#       space deliberately put in stack by $mod+Y/$mod+W is left alone.
#       Manual $mod+I goes through the same lock (--manual) but stays loud
#       and still force-sets bsp.
#     * Signals on window_created / window_destroyed / window_minimized /
#       window_deminimized / application_hidden / application_visible plus
#       space_changed / display_changed. The space/display pair exists
#       because `window --space` moves a window without any hookable-safe
#       event on the SOURCE space — re-snapping on every space entry heals
#       stale spaces lazily.
#     * $modShift+H/J/K/L append the auto-snap after a successful --warp,
#       because window_moved is the one event that CANNOT be hooked (see
#       the loop warning below).
#
#   FACTS THIS RESTS ON, from reading the yabai source (asmvik/yabai @
#   dd84572, post-7.1.25) — file:line cites are into that tree:
#     * window_created fires AFTER the window is inserted and tiled
#       (event_loop.c:590-596); window_destroyed fires AFTER sibling
#       promotion and re-tile (event_loop.c:613-624). A snap in the handler
#       always sees the final window set.
#     * Signal actions are double-forked and never block yabai's event loop
#       (event_signal.c:64-92). There is NO debounce — an app opening three
#       windows fires three actions, hence the flock.
#     * NEVER HOOK window_moved OR window_resized. They fire for yabai's OWN
#       moves — there is no self-origin suppression, and the comment at
#       window_manager.c:732-738 admits the frame cache cannot reliably
#       provide one. A snap hooked on either loops on its own warps.
#     * The events actually hooked cannot be produced by the snap itself
#       (it never creates, destroys, minimises, hides, or switches space),
#       which is the loop-safety argument. application_hidden/visible were
#       NOT source-traced like the others — worst case they fire before the
#       untile and one snap lands early; the next event corrects it.
#
#   VERIFY (the Step-0 checklist in the runbook below still applies first):
#     1. `yabai -m signal --list` shows the eight center-master-auto-* labels.
#     2. Open/close windows on a bsp space — layout re-snaps with NO keypress,
#        including down to 1 window and back up.
#     3. $mod+W (stack), then open a window — space STAYS stacked (the guard).
#     4. $modShift+J into the centre — columns survive without pressing $mod+I.
#     5. $modShift+2 a window away, $mod+Tab back — the source space healed
#        on re-entry (the space_changed signal).
#     6. Minimise + unminimise (cmd+M, then dock) — both directions re-snap.
#     7. Rapid-fire: open 4 windows quickly — flock serialises, final layout
#        correct. Kill switch if anything runs away:
#          for e in created destroyed minimized deminimized; do
#            yabai -m signal --remove center-master-auto-window_$e; done
#
# STEP 1.1 — THE IDEMPOTENCE GATE. IMPLEMENTED, NOT YET VERIFIED LIVE.
#   Response to the flashing: before issuing any layout command, the snap
#   now compares every window's frame against its target and exits when they
#   all match (see THE IDEMPOTENCE GATE in centerMaster). Space switches and
#   duplicate events become true no-ops; the one-reflow flash on REAL window
#   changes remains, and is the Step 2 criterion now: if THAT still grates
#   after the gate, the fork is the answer — a native layout applies the new
#   frames in one pass with no intermediate states.
#   VERIFY:
#     8. $mod+Tab between two snapped spaces repeatedly — nothing moves, no
#        flash. `time <centerMasterAuto store path>` on a correct space
#        returns in well under a second with no visible effect.
#     9. Open a window — exactly ONE reflow, then still. Close it — same.
#    10. $mod+I on a correct layout — silent no-op now (the gate runs in the
#        manual path too). To force a rebuild past the gate, perturb first
#        (resize with $mod+minus, then $mod+I).
#
# STEP 2 — OPTIONAL FORK: a native VIEW_MASTER_CENTER layout in yabai
#   itself. RESEARCHED, NOT STARTED. Decision gate: live with Step 1 for a
#   while — every open/close now visibly replays the tree surgery (warps,
#   ratio passes, the load-bearing 0.12s settles). If that churn grates, the
#   fork deletes this entire script plus the signal glue and computes frames
#   in one pass with no churn. Feasibility, verified by reading the source:
#     * yabai's frame pipeline is LAYOUT-AGNOSTIC — view_update ->
#       window_node_update -> window_node_flush dispatch on tree shape,
#       never on view->layout. `stack` is not a second engine, it is the bsp
#       tree kept at depth 0 with windows in the root's window_list.
#     * Touch points: enum + label (view.h:169-183), a third arm in
#       view_add_window_node_with_insertion_point (view.c:751-812), a forced
#       split variant of window_node_get_split (view.c:136-148), message.c
#       parsing, a post-removal normaliser (view_remove_window_node is
#       layout-agnostic but promotion will NOT restore 1/4|1/2|1/4 when the
#       centre closes), and a per-command decision on each `!= VIEW_BSP`
#       guard (window_manager.c:1754,1840,2004,2331,2360). ~300-500 lines.
#       No layout abstraction exists — ~25 scattered ad-hoc ifs.
#     * The algorithm to port is Hyprland's, already daily-driven on the
#       P14s: src/layout/algorithm/tiled/master/MasterAlgorithm.cpp at the
#       pinned input rev — LIST-based (ordered nodes + isMaster + percSize,
#       no tree), centre = mfact*W centred, slaves alternate left/right in
#       list order, sides stack vertically. ~120 lines for the centred case.
#       Note two semantic deltas from the snap here: Hyprland alternates
#       slaves by INSERTION order (this file assigns west-to-east by sorted
#       position) and puts the odd window left via ceil (this file uses
#       COUNT/2, floor-left). Pick one on purpose when porting.
#     * Packaging: point pkgs.yabai at the fork in modules/overlays.nix; the
#       per-store-path Accessibility re-grant cost is already being paid.
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
# ALSO VERIFIED LIVE on the 5120x1440 ultrawide (display 1, built-in demoted to
# display 2). The arithmetic holds at that width — targets were 1274 | 2548 |
# 1274, measured:
#
#   * ONE WINDOW: 2556 centred at x=1282, both outer quarters reserved.
#   * TWO WINDOWS: 1275 @ x=8 then 2550 @ x=1287, right quarter (1283px) EMPTY.
#   * THREE WINDOWS: 1275 | 2547 | 1273, all tiled. Idempotent over three passes.
#   * THREE TO EIGHT WINDOWS, after the centred-master snap was generalised to
#     subdivide the side columns. Every count holds the same three column widths
#     — 1275 | 2547 | 1273 — and only the stacking changes, left|centre|right:
#       3 -> 1|1|1   4 -> 2|1|1   5 -> 2|1|2
#       6 -> 3|1|2   7 -> 3|1|3   8 -> 4|1|3
#     Each was measured after the count changed under it (windows opened, closed
#     and moved between spaces), and each is idempotent over three presses.
#   * MOVING A WINDOW INTO THE CENTRE used to destroy the layout: the centre is
#     the one region WIDER than tall (2547x1393), so bsp split it side by side
#     and gave 1275 | 1271 | 1271 | 1273 — four columns, no centre. Moving into a
#     SIDE column was always safe, those being taller than wide. With the centre
#     armed via `window --insert south` the same move now STACKS into the centre
#     (2547px x2) and the three columns survive. Verified after three $mod+I
#     presses, which also proves the double-set idiom below: a single `--insert`
#     would have toggled itself back off on the second press.
#   * Firefox sat in the CENTRE slot at 2550px and in a SIDE column at 1275px —
#     its 500px minimum width, which makes it unusable as a side column on the
#     1512px built-in, is a non-issue here. As predicted, and it is the only
#     reason that prediction is now more than a guess.
#   * THE STALE-ENTRY FILTER EARNS ITS KEEP HERE TOO. Closing a test window left
#     `query --windows` reporting id=13352, app "ghostty" lower-cased, empty
#     title, is-visible false, has-ax-reference FALSE — a fourth "window" that
#     would have put a two-window space into the three-or-more branch and left
#     two real windows overlapping.
#
# STILL UNVERIFIED: the multi-monitor bindings ($mod+U, the arrows, and their
# $modShift variants) have never been driven, on either display arrangement.
# ALSO UNVERIFIED: everything Step 1 added — the signal registrations, the
# flock wrapper, the stack-space guard, and the two behavioural deltas it
# rides on (is-minimized/is-hidden filtering, arm_centre removal). Run the
# Step 1 VERIFY list in the plan block above before trusting any of it.
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
#   4. THE LAYOUT-PERSISTENCE BUG, the same mistake as 3 in a second piece of
#      per-space state. The snap set padding and ratios but never checked
#      `space --layout`. On a space left in `stack` by $mod+Y, ratios are a
#      silent no-op, so all that landed was the padding — and with the LEFT AND
#      RIGHT PADDING STILL 1282 FROM A ONE-WINDOW SNAP, every window sat
#      full-size in the middle half of the ultrawide. Pressing $mod+I again
#      could not recover it. Found on the ultrawide, but nothing about it was
#      display-specific; it was just as broken on the built-in.
#   5. THE STALE-READ BUG, in the generalised snap. The root boundary is fixed
#      by measuring the centre window and moving its left edge, and the measure
#      ran immediately after the ratio commands — so it read the PREVIOUS
#      layout, computed a delta of roughly zero, took the "already correct"
#      early exit and never moved anything. Gave 510 | 3057 | 1528 on the first
#      press and the right answer on the second, which is exactly how a missing
#      settle hides: press the key twice and it looks fine.
#   6. THE MIRRORED-LAYOUT BUG, from assuming `--warp` puts the warped window on
#      a predictable side of the split it creates. It does not — it depends on
#      where the window came from. With an ODD number of windows the centre
#      window landed as the root's FIRST child, so the layout came out mirrored:
#      the centre alone against the left screen edge at 1697px and the left
#      column exiled to the far right at 2550px. Even counts were unaffected,
#      which made it look like an arithmetic bug rather than a topology one. It
#      also disarmed bug 5's fix, because a window on the screen edge has no
#      ancestor boundary for `--resize` to move.
#
# REJECTED, WITH MEASUREMENTS, SO IT IS NOT RETRIED:
#
#   * PINNING `split_type horizontal` ON THE SPACE. It is a per-space setting
#     (vertical|horizontal|auto, `auto` meaning "choose from the region's
#     width/height ratio"), and forcing `horizontal` looked like the clean fix
#     for the four-column bug: every new split becomes top-and-bottom, so an
#     inserted window stacks into a column and a fourth column is unreachable.
#     It works for insertion — measured, a window moved into a snapped space
#     stacked at x=8 y=39/738/1087 and the centre never moved.
#
#     IT BREAKS THE SNAP ITSELF, and the mechanism is the promotion rule above.
#     Step 1 toggles the root vertical; step 2 then warps a window out of the old
#     root, which collapses it and promotes the root-to-be, which is re-derived
#     as HORIZONTAL because that is what the space now demands. The whole layout
#     comes back as a vertical stack: measured 5104px x2 | 1699px x1, reproduced
#     identically on three consecutive runs. Under `auto` the same promotion
#     happens but re-derives a full-width region as vertical, which is the only
#     reason any of this works — the snap has always been relying on the default,
#     not overriding it.
#
#     So `split_type` stays `auto`, and the centre slot is protected per-window
#     with `--insert` instead. If you are tempted by this again: the tell is that
#     the FIRST press of $mod+I looks fine and the SECOND collapses the layout.
#
# THE LESSON, and the reason for this section: the man page tells you WHICH
# COMMANDS EXIST and WHAT NEEDS SIP. It does not tell you HOW bsp BEHAVES. Every
# behavioural fact below had to be discovered by driving it:
#
#   * split direction follows container aspect ratio, not config;
#   * `window --ratio` and `window --toggle split` reach only a window's
#     IMMEDIATE parent split, so a node with no window directly beneath it —
#     the root, once both side columns hold more than one window — cannot be
#     named at all. `window --resize` is the way in: it moves an EDGE and yabai
#     walks up to whichever ancestor owns it;
#   * `window --warp` picks which side of the new split the window lands on from
#     the DIRECTION IT TRAVELLED, not from the argument order — warping the same
#     window onto the same target repeatedly ALTERNATES it between first_child
#     and second_child;
#   * yabai APPLIES FRAMES ASYNCHRONOUSLY — a query issued straight after a
#     layout command still reports the previous geometry. THE TREE METADATA IS
#     NOT ASYNC, though: `split-type` and `split-child` read correctly the
#     instant a `--warp` or `--toggle split` returns. Measured over five trials
#     of each, immediate versus settled. So settle before reading FRAMES, and
#     never bother settling before reading SHAPE;
#   * A NODE'S SPLIT ORIENTATION DOES NOT SURVIVE PROMOTION TO ROOT. Set a
#     node vertical with `--toggle split`, then remove a window that was the
#     old root's other child — the old root collapses, your node takes its
#     place, and it comes back HORIZONTAL. Measured under split_type
#     `horizontal` AND under `auto`. An earlier draft of this bullet called
#     that "re-derived", which the source says is the WRONG MECHANISM: a
#     node's split is STICKY (nothing in the codebase ever resets ->split to
#     SPLIT_NONE), and promotion copies the surviving child's contents into
#     the parent EXCEPT the split field, so the promoted node wears the OLD
#     PARENT's orientation (view_remove_window_node, view.c:621-728; the
#     auto-derivation at view.c:136-148 only runs while split is still
#     unset). Same practical rule — the root's orientation cannot be set
#     early and relied upon — plus a corollary the old wording hid: a leaf
#     that was ONCE an internal node re-splits with its STALE old
#     orientation, not a fresh aspect-derived one. The want_split
#     corrections in the snap are what absorb both;
#   * `window --insert <DIR>|stack` overrides the aspect-ratio choice for the
#     next insertion into that window, and is CONSUMED BY THAT INSERTION —
#     measured, an armed target split horizontal and the very next warp onto
#     it split vertical again; the source agrees (insert_dir zeroed at
#     view.c:775). Its state is NOT exposed by any query — verified against
#     the full serialisation list, window.h:32-64. The man page calls it a
#     toggle and the source implements one (window_manager.c:1769-1776), but
#     the toggle WAS NOT REPRODUCIBLE here: `--insert south` twice still
#     armed the window. Unresolved — possibly an insertion consumed the mode
#     between the two presses. Treat the toggle as real when writing code.
#     TWO MORE FACTS FROM THE SOURCE, both unmeasured here so far: the armed
#     node HIJACKS NEWLY CREATED WINDOWS, not just warps — the marked node is
#     checked BEFORE the focused-window lookup (view.c:768-782), so an armed
#     centre catches the next window opened ANYWHERE on that space — and
#     `--insert stack` makes the caught insertion JOIN the node as a
#     yabai-stack instead of splitting it (view.c:773-780). The hijack is
#     half of why arm_centre was retired; see the note at its old site;
#   * `space --padding` persists until something overwrites it, and so does
#     `space --layout` — a layout key press outlives the windows it was aimed at;
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
# AND THERE IS NO EXTENSION POINT TO DO IT PROPERLY. The obvious question when
# reading the tree surgery below is "why not just write a layout algorithm and
# hook it in?" — the answer is that yabai has nowhere to hook it. Verified on
# 7.1.25 rather than assumed:
#
#   * `space --layout` accepts exactly bsp|stack|float. Three layouts, compiled
#     in; `--layout custom` is rejected as an unknown value.
#   * the man page has ZERO matches for plugin, hook, extension api or custom
#     layout;
#   * signals run AFTER an event is processed ("react to some event that has
#     been processed"), so they can observe the tiling decision and never
#     influence it.
#
# So the only lever is: let bsp tile, then reach in and rewrite its tree. Every
# awkward thing in centerMaster — the warp sequence, the orientation toggles,
# the `--resize` to reach an unaddressable root — is a symptom of driving an
# engine from outside its intended interface, not of the code being needlessly
# clever. If that trade ever stops being worth it, the tool that HAS the missing
# API is Amethyst, whose custom layouts are JavaScript files exposing
# getFrameAssignments(windows, screenFrame, state) -> frames keyed by window id.
# READ FROM ITS DOCS, NOT DRIVEN — by the standard this header sets, treat that
# as a lead to verify rather than a fact, and probe it the same way before
# betting anything on it. It would also be a window-manager migration rather
# than a refactor: it costs the SIP-safe space and display commands verified
# above and every binding in this file.
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
#      THEN THE TWO CASES THAT BROKE EVERY EARLIER VERSION:
#        a. GO PAST THREE WINDOWS. Open up to eight, pressing $mod+I at each
#           count. The three column widths must not move (1275 | 2547 | 1273 on
#           the ultrawide); only the stacking changes, 1|1|1 through 4|1|3. An
#           ODD count is the one that catches mirrored-tree bugs, because the
#           even ones can look right by accident.
#        b. MOVE A WINDOW INTO THE CENTRE with $mod+Shift+H/L. It must STACK in
#           the centre, not open a fourth column. This is the case `--insert`
#           arming exists for, and it is the first thing to break if the snap's
#           final step is ever reordered.
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
#   * FOUR COLUMNS AFTER MOVING A WINDOW -> the centre slot's `--insert` arming
#     is CONSUMED BY ONE INSERTION, so the second window moved into the centre
#     falls back to the aspect ratio and splits it side by side. Measured: warp
#     into an armed centre gave horizontal, the very next warp gave vertical.
#     $mod+I rebuilds AND re-arms; there is no state to inspect because the mode
#     is not exposed by `query --windows`.
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
      # SINCE STEP 1 THIS SELF-MAINTAINS: the signals registered in
      # extraConfig below re-run it (through centerMasterAuto) whenever the
      # window set changes, so $mod+I is now the manual override — the loud
      # entry point that also FORCES bsp, where the auto path refuses to
      # touch a non-bsp space. Unlike the AeroSpace version, every window
      # count is expressible and nothing floats.
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

          # --quiet is the signal-driven entry, passed by centerMasterAuto.
          # Under auto-snap every notify() here would fire on ORDINARY WINDOW
          # EVENTS — "No tiled windows" on closing the last window of a
          # space, the minimum-size warning on every event while Firefox sits
          # in a side column of the built-in display — so the auto path
          # silences them all. Manual $mod+I stays loud.
          if [ "''${1:-}" = "--quiet" ]; then QUIET=1; else QUIET=0; fi

          notify() {
            if [ "$QUIET" = "1" ]; then return 0; fi
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

          # ASSERT bsp BEFORE MEASURING ANYTHING. `space --layout` is PERSISTENT
          # PER-SPACE STATE, exactly like padding, and the centred-master layout
          # is a bsp TREE — so if the space was left in `stack` by $mod+Y, every
          # `--ratio` below is a silent no-op and each branch's padding is the
          # only thing that lands. Measured on the 5120 ultrawide with two
          # windows on a stacked space: both windows full-size at x=1282 w=2556,
          # because the LEFT/RIGHT PADDING WAS STILL 1282 FROM A ONE-WINDOW SNAP
          # (OUTER + SIDE) and a stack simply fills whatever it is given. The
          # visible symptom is "centred mode, but every window is in the middle" —
          # and pressing $mod+I again could not fix it, because nothing in here
          # ever looked at the layout. Setting bsp when already bsp is a no-op:
          # three consecutive presses gave byte-identical geometry.
          yabai -m space --layout bsp >/dev/null 2>&1 || true

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
          # TWO MORE FILTERS SINCE STEP 1: is-minimized and is-hidden. The
          # snap now runs FROM the minimise/hide events, and a minimised or
          # cmd+H-hidden window is untiled by yabai but still present in the
          # query — counting it would push the space into the wrong branch,
          # the same failure mode as the stale-entry bug above. This was a
          # latent bug in the manual snap too (press $mod+I with a minimised
          # window and it counted); the events just made it unavoidable.
          WINS=$(yabai -m query --windows --space \
                   | jq -c '[.[] | select(."is-floating" == false
                                          and ."has-ax-reference" == true
                                          and ."is-minimized" == false
                                          and ."is-hidden" == false)
                                 | {id, x: .frame.x, y: .frame.y,
                                        w: .frame.w, h: .frame.h}]
                            | sort_by(.x, .y)')
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

          # THE IDEMPOTENCE GATE (Step 1.1). If every window already sits in
          # its target frame, exit before issuing a single layout command.
          #
          # WHY: the first live run of the auto-snap produced LOTS OF
          # FLASHING, and most of it was pointless — the branches below
          # replay the FULL tree surgery (warps, orientation toggles, settle
          # sleeps) even when the layout is already correct, and Step 1 runs
          # them on every space_changed. "Idempotent" was only ever true of
          # the FINAL geometry; the transient states in between are exactly
          # the flashing. This gate makes the no-op case actually a no-op.
          # The flash that remains — one reflow when the window set REALLY
          # changed — is inherent to doing layout through the command API,
          # and is the churn the Step 2 fork decision is about.
          #
          # WHAT IT CHECKS, against the same west-to-east partition the 3+
          # branch uses (left = COUNT/2, then centre, rest right): every
          # window's x and w against its column's target, and heights EQUAL
          # WITHIN each side column (a drifted horizontal ratio shows up as
          # unequal heights; absolute height targets would need the menu-bar
          # height, which the display frame does not expose). Tolerance 6px
          # — the measured rounding residue was <= 3px (see STATUS block).
          #
          # FRAMES ARE ASYNC (see step 5 below), so an event arriving
          # mid-settle can read half-applied frames and fail the gate
          # spuriously — the cost is one redundant snap, which is what
          # happened on every event before the gate existed.
          if [ "$COUNT" -ge 1 ]; then
            if printf '%s' "$WINS" \
                 | jq -r '.[] | "\(.x) \(.w) \(.h)"' \
                 | awk -v count="$COUNT" -v outer="$OUTER" -v inner="$INNER" \
                       -v side="$SIDE" -v avail="$AVAIL" -v monw="$MON_W" '
                     function bad(a, b) { d = a - b; return d > 6 || d < -6 }
                     { x[NR - 1] = $1; w[NR - 1] = $2; h[NR - 1] = $3 }
                     END {
                       if (count == 1) {
                         if (bad(x[0], outer + side)) exit 1
                         if (bad(w[0], monw - 2 * (outer + side))) exit 1
                         exit 0
                       }
                       cx = outer + side + inner
                       if (count == 2) {
                         if (bad(x[0], outer) || bad(w[0], side)) exit 1
                         if (bad(x[1], cx)) exit 1
                         if (bad(w[1], monw - (outer + side) - cx)) exit 1
                         exit 0
                       }
                       nl = int(count / 2)
                       cw = avail / 2
                       rx = cx + cw + inner
                       rw = monw - outer - rx
                       for (i = 0; i < count; i++) {
                         if (i < nl)       { tx = outer; tw = side }
                         else if (i == nl) { tx = cx;    tw = cw }
                         else              { tx = rx;    tw = rw }
                         if (bad(x[i], tx) || bad(w[i], tw)) exit 1
                       }
                       for (i = 1; i < nl; i++)
                         if (bad(h[i], h[0])) exit 1
                       for (i = nl + 2; i < count; i++)
                         if (bad(h[i], h[nl + 1])) exit 1
                       exit 0
                     }'
            then
              exit 0
            fi
          fi

          # SORTED WEST TO EAST, THEN NORTH TO SOUTH, and only ids are read
          # back: the layout branches build the tree from split-type and
          # split-child rather than measuring widths. The y in the sort is what
          # makes a STACKED COLUMN read in visual order — sorting on x alone
          # leaves windows sharing a column in whatever order the query
          # returned, so the partition below would shuffle them on every press.
          nth_id() { printf '%s' "$WINS" | jq -r ".[$1].id"; }

          # ARM_CENTRE IS RETIRED (Step 1), so it is not re-invented. It used
          # to `--insert south` the centre window at the end of every branch,
          # protecting the one thing a rebuild could not: the centre is the
          # only region WIDER than tall (2547x1393 on the ultrawide), so a
          # window moved into it split SIDE BY SIDE and the layout became four
          # columns — measured 1275 | 1271 | 1271 | 1273, the centre gone.
          # (Moving into a SIDE column was always safe: taller than wide, so
          # it stacks.) With it armed, the same move stacked into the centre
          # at 2547px x2 and the columns survived.
          #
          # TWO REASONS IT DIED, both from the auto-snap:
          #
          #   1. REDUNDANT. Any centre-destroying insertion now fires a
          #      hookable event (or rides a keybinding that appends the snap),
          #      and the rebuild restores the three columns without the arm.
          #      The arm only ever bought "not destroyed BETWEEN key
          #      presses", and there is no between any more.
          #   2. ACTIVELY HARMFUL under signals, per the yabai source: the
          #      armed node hijacks NEWLY CREATED windows, not just warps —
          #      view->insertion_point is checked before the focused-window
          #      lookup (view.c:768-782). Re-armed at the end of every
          #      auto-snap, EVERY new window on the space would land on the
          #      centre regardless of focus, fire the created signal, get
          #      pulled back out by the rebuild, and re-arm the trap. Endless
          #      churn with a surprise placement in the middle of it.
          #
          # ALSO CONSIDERED AND REJECTED: swapping south for `--insert stack`
          # (the caught window would JOIN the centre as a yabai-stack,
          # view.c:773-780) — a nicer arm, but reason 2 applies to any armed
          # mode, so it dies the same way.
          #
          # $modShift+Return (`window --insert south` on the focused window)
          # remains the MANUAL one-shot version of this gesture when you want
          # the next window to land somewhere specific; the auto-snap will
          # re-even the ratios right after it lands.

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

            # --- THREE OR MORE: 1/4 | 1/2 | 1/4, side columns subdivided -----
            # One window takes the centre half. EVERY OTHER WINDOW STACKS INTO
            # THE TWO OUTER QUARTERS, which subdivide again for each window
            # added rather than growing a fourth column. No padding beyond the
            # base, so the tree fills the screen and the ratios do the work.
            #
            # THE TARGET TREE — the only shape that produces this layout:
            #
            #   root (vertical)
            #     |- L column   (horizontal chain: L0, L1, ... stacked)
            #     '- (vertical)
            #          |- C     the centre window
            #          '- R column   (horizontal chain: R0, R1, ... stacked)
            #
            # Windows are assigned west to east out of the x,y-sorted list, so
            # the layout is IDEMPOTENT — re-reading after a snap gives the same
            # partition and every command below becomes a no-op. The odd window
            # goes left (COUNT/2 on the left, the rest on the right), so the
            # counts run 1|1|1, 2|1|1, 2|1|2, 3|1|2, 3|1|3 as windows arrive.
            #
            # THIS REPLACED a three-window special case plus `space --balance`
            # for anything larger. Balance was measured on the ultrawide with
            # six windows and gives FOUR EQUAL COLUMNS of 1271|1271|1273|1275 —
            # no centre at all, which is the whole point of the key.
            *)
              yabai -m space --padding "abs:$OUTER:$OUTER:$OUTER:$OUTER"
              yabai -m space --gap "abs:$INNER"

              NL=$((COUNT / 2))
              NR=$((COUNT - 1 - NL))
              CID=$(nth_id "$NL")

              prop() {
                yabai -m query --windows --window "$1" | jq -r --arg k "$2" '.[$k]'
              }

              # bsp PICKS SPLIT DIRECTION FROM THE REGION'S ASPECT RATIO, not
              # from anything configurable, so every node has to be corrected
              # after it is created — on a tall region a new split comes out
              # horizontal and produces a stack where a column was wanted.
              # split-type reports a window's PARENT split, so a node can be
              # named by any window sitting directly beneath it, and
              # `--toggle split` flips exactly that node.
              want_split() { # id, wanted split-type of that window's parent
                if [ "$(prop "$1" split-type)" != "$2" ]; then
                  yabai -m window "$1" --toggle split >/dev/null 2>&1 || true
                fi
              }

              # `--ratio` names the fraction given to the FIRST child, so which
              # side the addressed window sits on decides whether it receives
              # the value or its complement. split-child answers that.
              set_ratio() { # id, fraction wanted for THIS window's own side
                if [ "$(prop "$1" split-child)" = "first_child" ]; then
                  yabai -m window "$1" --ratio "abs:$2" >/dev/null 2>&1 || true
                else
                  yabai -m window "$1" --ratio \
                    "abs:$(awk -v r="$2" 'BEGIN { printf "%.4f", 1 - r }')" \
                    >/dev/null 2>&1 || true
                fi
              }

              # `--warp` PICKS WHICH SIDE OF THE NEW SPLIT THE WINDOW LANDS
              # ON FROM THE DIRECTION IT TRAVELLED, not from the argument order,
              # so the same call yields (target, window) or (window, target)
              # depending only on where the window happened to be. That is
              # invisible in the widths — set_ratio corrects for it — but it
              # MIRRORS THE LAYOUT: measured with seven windows, the centre
              # window landed as the root's FIRST child and came out alone
              # against the left screen edge at 1697px with the left column
              # exiled to the far right at 2550px. It also disarms step 5, since
              # a window on the screen edge has no ancestor boundary to move.
              #
              # Both children are leaves at the moment of the warp — nothing has
              # been warped onto either of them yet — so `--swap` exchanges
              # exactly the two windows and nothing else.
              warp_onto() { # id, target — leaves id as the target's SECOND child
                yabai -m window "$1" --warp "$2" >/dev/null 2>&1 || true
                if [ "$(prop "$1" split-child)" = "first_child" ]; then
                  yabai -m window "$1" --swap "$2" >/dev/null 2>&1 || true
                fi
              }

              # STEP 1 — CONSTRUCT THE ROOT, AND SET IT WHILE IT IS STILL
              # ADDRESSABLE. Warping the centre window onto the westmost one
              # makes the two of them siblings, and at THIS INSTANT both are
              # leaves of that node — the only moment the root can be named at
              # all. `--toggle split` and `--ratio` reach a window's IMMEDIATE
              # parent and nothing else, so once the columns are built neither
              # of the root's children is a window and the root becomes
              # unreachable. Measured: with the columns in place the root ratio
              # stayed at 0.5 and the left group sat at 2550px, half the
              # ultrawide, with no window able to name the node holding it.
              warp_onto "$CID" "$(nth_id 0)"
              want_split "$CID" vertical
              set_ratio "$CID" 0.75

              # STEP 2 — GROW THE COLUMNS. Each warp splits the leaf it targets,
              # so warping window k onto window k-1 chains them: L0 beside
              # (L1 beside (L2 ...)). Every target is a window already placed by
              # an earlier warp, which is what makes the sequence sound — a warp
              # only ever REMOVES an unplaced window, so no relation built here
              # is ever destroyed by a later one, and after COUNT-1 warps the
              # COUNT-1 relations are exactly the target tree.
              I=1
              while [ "$I" -lt "$NL" ]; do
                warp_onto "$(nth_id "$I")" "$(nth_id "$((I - 1))")"
                I=$((I + 1))
              done
              J=0
              while [ "$J" -lt "$NR" ]; do
                if [ "$J" -eq 0 ]; then
                  warp_onto "$(nth_id "$((NL + 1))")" "$CID"
                else
                  warp_onto "$(nth_id "$((NL + 1 + J))")" \
                    "$(nth_id "$((NL + J))")"
                fi
                J=$((J + 1))
              done

              # STEP 3 — ORIENT EVERY NODE. Columns are horizontal splits (top
              # and bottom); the centre/right divide is vertical. C names a
              # DIFFERENT node now than it did in step 1: with R0 warped onto
              # it, C's parent is the centre-versus-right-column split rather
              # than the root. A chain node is named by its own first window,
              # so the loops stop one short — the last window in a column shares
              # its parent with the one before it.

              want_split "$CID" vertical
              I=0
              while [ "$I" -lt "$((NL - 1))" ]; do
                want_split "$(nth_id "$I")" horizontal
                I=$((I + 1))
              done
              J=0
              while [ "$J" -lt "$((NR - 1))" ]; do
                want_split "$(nth_id "$((NL + 1 + J))")" horizontal
                J=$((J + 1))
              done

              # STEP 4 — RATIOS. The centre keeps two thirds of everything east
              # of the left column, which is AVAIL/2 once the root is a quarter.
              # In a column of k windows the first takes 1/k of it and the rest
              # share what is left, recursively, so every window ends up the
              # same height.
              set_ratio "$CID" 0.6667
              I=0
              while [ "$I" -lt "$((NL - 1))" ]; do
                set_ratio "$(nth_id "$I")" \
                  "$(awk -v k="$((NL - I))" 'BEGIN { printf "%.4f", 1 / k }')"
                I=$((I + 1))
              done
              J=0
              while [ "$J" -lt "$((NR - 1))" ]; do
                set_ratio "$(nth_id "$((NL + 1 + J))")" \
                  "$(awk -v k="$((NR - J))" 'BEGIN { printf "%.4f", 1 / k }')"
                J=$((J + 1))
              done

              # STEP 5 — THE ROOT BOUNDARY, the one thing step 1 cannot be
              # trusted to have kept. `--resize` moves an EDGE and yabai walks
              # up to whichever ancestor owns it: C's own parent is a vertical
              # split owning C's RIGHT edge, so asking for C's LEFT edge lands
              # on the root. That is the only handle on it once the columns
              # exist. Verified live — one pass took the left group from 2550px
              # to 1275 and gave 1275 | 2547 | 1273.
              #
              # THE SLEEP IS LOAD-BEARING, and its absence is what made the
              # first version of this branch need TWO key presses to settle.
              # yabai APPLIES FRAMES ASYNCHRONOUSLY: query the geometry straight
              # after the ratio commands and it still reports the PREVIOUS
              # layout. Measured on a four-window space — the read came back at
              # the old centre x, DX computed as roughly zero, the tolerance
              # below took the break, and the root was never corrected at all.
              # The visible symptom was a correct centre-to-right split inside a
              # wrong root: 510 | 3057 | 1528 instead of 1274 | 2548 | 1274.
              # A second press then looked fine, which is exactly how this hides.
              TARGET_X=$((OUTER + SIDE + INNER))
              for _ in 1 2 3; do
                sleep 0.12
                CUR_X=$(yabai -m query --windows --window "$CID" \
                          | jq -r '.frame.x | floor')
                DX=$((TARGET_X - CUR_X))
                if [ "$DX" -gt -3 ] && [ "$DX" -lt 3 ]; then break; fi
                yabai -m window "$CID" --resize "left:$DX:0" >/dev/null 2>&1 || true
              done
              sleep 0.12

              # A WINDOW WITH A MINIMUM SIZE CAN DEFEAT ALL OF THIS, and it
              # takes the rest of the space down with it. Firefox measured a
              # hard floor of 500px wide: asked for 450, 400, 372, 300 and 200
              # it returned 500 every time. That makes it unusable as a side
              # column on the 1512px built-in, where a quarter is 372px, and a
              # non-issue on the ultrawide, where a quarter is 1274px. Report it
              # rather than silently producing a broken layout — the honest fix
              # is to put such a window in the CENTRE slot.
              W_L=$(yabai -m query --windows --window "$(nth_id 0)" \
                      | jq -r '.frame.w | floor')
              if [ "$W_L" -gt "$((SIDE + SIDE / 2))" ]; then
                notify "Centred master" \
                  "Left column will not go below ''${W_L}px (minimum size) — layout is approximate"
              fi
              exit 0
              ;;
          esac
        '';
      };

      # THE STEP-1 ENTRY POINTS: every path into the snap goes through here so
      # that every path is SERIALISED. yabai's signal system has no debounce —
      # an app opening three windows fires three actions (event_signal.c
      # forks per subscriber, per event) — and the snap is not safe to run
      # concurrently with itself: two interleaved runs warp against each
      # other's half-built trees. flock makes bursts queue; each queued run
      # re-queries from scratch, so the LAST run always lands the layout for
      # the final window set and the earlier ones were at worst wasted work.
      # (pkgs.flock is the discoteq port — macOS ships no flock(1).)
      #
      # Two modes:
      #
      #   (no args)  the SIGNAL path: quiet, and REFUSES to touch a space
      #              whose layout is not bsp. That guard is what keeps
      #              $mod+W/$mod+Y meaningful — without it, the first window
      #              event on a deliberately-stacked space would force it
      #              back to bsp (centerMaster asserts bsp for the manual
      #              case) and stack mode would become unusable.
      #   --manual   the $mod+I path: same lock (so a keypress cannot race a
      #              signal), but loud, and no guard — the manual gesture is
      #              exactly "make this space centred-master, whatever it is".
      #
      # The lock ORDERING matters: the bsp check runs AFTER the lock is
      # taken, because the layout can change while waiting (e.g. queued
      # behind a --manual run that is about to force bsp).
      centerMasterAuto = pkgs.writeShellApplication {
        name = "yabai-center-master-auto";
        runtimeInputs = [
          pkgs.flock
          pkgs.yabai
          pkgs.jq
        ];
        text = ''
          LOCK="/tmp/yabai-center-master-$(id -u).lock"

          case "''${1:-}" in
            --manual)
              exec flock "$LOCK" ${lib.getExe centerMaster}
              ;;
            --locked)
              # Below the lock now — fall through to the guarded quiet snap.
              ;;
            *)
              exec flock "$LOCK" "$0" --locked
              ;;
          esac

          # Signals must never notify, so every failure here is a silent
          # skip: a dead server during a signal storm would otherwise spam a
          # notification per queued event.
          TYPE=$(yabai -m query --spaces --space 2>/dev/null | jq -r '.type') \
            || exit 0
          if [ "$TYPE" != "bsp" ]; then exit 0; fi
          exec ${lib.getExe centerMaster} --quiet
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
        #
        # THE APPENDED AUTO-SNAP IS THE window_moved GAP CLOSING (Step 1):
        # a warp reshapes the tree but creates/destroys nothing, so none of
        # the hooked signals fire, and window_moved — the event that WOULD
        # fire — is unhookable (it also fires for the snap's own warps; see
        # the plan block). So the one keybinding that moves windows within a
        # space carries its own re-snap. && so a warp that failed at the
        # layout edge (exit 1, layout unchanged) skips the rebuild.
        ++ lib.mapAttrsToList (
          k: d: bind modShift k "yabai -m window --warp ${d} && ${lib.getExe centerMasterAuto}"
        ) directions

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
        # Follow the window to its new Space, matching AeroSpace's
        # move-node-to-workspace, which focuses the target. The follow is a
        # TRAILING `--focus` FLAG, not a `^` prefix on the selector — `^` is
        # RULE syntax (`rule --add space='^3'`, yabai.asciidoc:658-660) and
        # SPACE_SEL does not accept it (asciidoc:108). An earlier draft here
        # wrote `--space ^<n>` and every one of these ten keys died with
        # `value '^3' is not a valid option for SPACE_SEL`, exit 1 — measured
        # live, which is also how the working form below was confirmed
        # (window moved AND target space focused, exit 0). `--focus` is
        # undocumented on `window --space`; the docs list the flag for no
        # window subcommand except `--focus` itself.
        ++ map (w: bind modShift w.key "yabai -m window --space ${w.index} --focus") workspaces

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
          # was its centreHalf. Through centerMasterAuto --manual since Step 1
          # so the keypress takes the same flock as the signals — loud, and
          # still forces bsp, unlike the signal path.
          (bind mod "i" "${lib.getExe centerMasterAuto} --manual")

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
          #
          # SHARES A MECHANISM WITH THE CENTRED-MASTER SNAP. centerMaster arms
          # the CENTRE window with this very command so a window moved into it
          # stacks instead of carving out a fourth column. Pressing this key on
          # an already-armed centre was measured to REINFORCE the arming, not
          # clear it, despite the man page describing --insert as a toggle — so
          # the manual key and the snap do not fight. Pressing it with another
          # direction (there is no such binding today) would override the snap
          # until the next $mod+I.
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

        # THE STEP-1 SIGNALS: this is what makes the centred master
        # SELF-MAINTAINING. Each one re-runs the snap (through the flock +
        # bsp-guard in centerMasterAuto) after an event that changes the
        # visible window set. Registered here because nix-darwin's yabairc is
        # a store path in the launchd plist, so edits to this list reload the
        # agent and re-register from a clean table — no duplicate-label
        # handling needed. Inspect live with `yabai -m signal --list`;
        # kill switch: `yabai -m signal --remove center-master-auto-<event>`.
        #
        # THE EVENT LIST IS A LOOP-SAFETY ARGUMENT, not a convenience pick.
        # window_moved and window_resized are DELIBERATELY ABSENT: yabai's
        # own tiling moves fire them (no self-origin suppression —
        # window_manager.c:732-738 admits the frame cache cannot provide
        # one), so hooking either makes the snap trigger itself forever. The
        # events below cannot be produced by the snap: it never creates,
        # destroys, minimises, hides, or switches space.
        #
        #   window_created      fires AFTER the window is tiled
        #                       (event_loop.c:590-596), so the snap sees it
        #   window_destroyed    fires AFTER sibling promotion
        #                       (event_loop.c:613-624); also covers app quit
        #   window_minimized /  a minimised window is untiled but still
        #   window_deminimized  queryable — hence the is-minimized filter
        #   application_hidden / cmd+H, same shape as minimise. NOT
        #   application_visible  source-traced; worst case a snap runs early
        #                        and the next event corrects it
        #   space_changed /     lazy healing: `window --space` changes the
        #   display_changed     SOURCE space with no hookable event, so every
        #                       space entry re-snaps instead. Idempotent =
        #                       byte-identical geometry when already correct
        extraConfig = lib.concatMapStringsSep "\n" (event:
          "yabai -m signal --add event=${event} action='${lib.getExe centerMasterAuto}' label=center-master-auto-${event}"
        ) [
          "window_created"
          "window_destroyed"
          "window_minimized"
          "window_deminimized"
          "application_hidden"
          "application_visible"
          "space_changed"
          "display_changed"
        ];

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
          #
          # NOW LOAD-BEARING, not just a preference. The centred-master snap
          # builds each side column as a chain of warps and relies on the warped
          # window landing BELOW the one it split; that is what makes a column
          # read top-to-bottom in the same order as the x,y-sorted window list,
          # which in turn is what makes the snap idempotent. Flip this to
          # first_child and the columns still tile, but every press reverses
          # their vertical order and the layout never settles.
          window_placement = "second_child";
          split_ratio = 0.5;
          # OFF, and it matters even more since Step 1: auto_balance
          # re-equalises every ratio whenever a window opens or closes —
          # i.e. it would fight the auto-snap ON THE SAME EVENTS, yabai
          # flattening the ratios internally while the signal-driven snap
          # re-asserts 1/4|1/2|1/4 from outside. With it off, the signals are
          # the only thing reacting to window events.
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
