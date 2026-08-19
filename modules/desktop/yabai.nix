# yabai + skhd — the tiling alternative to modules/desktop/aerospace.nix.
#
# ============================================================================
# THIS RUNS A FORKED yabai. The centred-master layout is NATIVE now.
# ============================================================================
#
# The plan block that used to live here (Steps 0..2: manual snap, signal-driven
# auto-snap, idempotence gate) ended at its own decision gate: Step 2, the
# fork, was executed on 2026-08-19 and the entire shell harness — centerMaster
# (~500 lines of tree surgery), centerMasterAuto (flock + bsp guard), eight
# yabai signals, and the warp-appended re-snap — was deleted with it. The full
# account of that era, including the seven measured bugs and the rejected
# experiments, is in this file's history at nix-config commit 37f559c. Read it
# before reinventing any of it; the bsp behavioural facts recorded there
# (split-from-aspect-ratio, warp side chosen by travel direction, promotion
# discarding orientation, async frames) are still true of bsp — they just no
# longer have anything to break here, because no script drives bsp any more.
#
# THE FORK adds a fourth layout, `master_center`, beside bsp|stack|float:
#
#   * quarter | centred master | quarter. One window: the centred master with
#     BOTH side columns empty. Two: left column + master, right column EMPTY.
#     Three or more: side columns subdivide vertically, first COUNT/2 slots
#     west, then the master, the rest east — the same 1|1|1 .. 4|1|3 series
#     the shell snap produced.
#   * `yabai -m config center_ratio 0.5` sets the master's fraction of the
#     available width (0.1..0.9, live-applies to master_center spaces).
#     hyprland.nix runs mfact = 0.45; set that here if the machines should
#     match exactly. The side columns split the remainder equally.
#   * SELF-MAINTAINING BY CONSTRUCTION: frames are computed in ONE pass inside
#     view_update, so every open/close/warp/space-switch lands the final
#     geometry with no intermediate states — the flashing that motivated the
#     fork cannot occur, and there is no event glue to wedge.
#   * A slot holds a window STACK, not just a window: `window --insert stack`
#     on a slot makes the next window join it, and the slot count (not the
#     window count) drives the column layout. Richer than the shell snap,
#     which counted windows.
#
# HOW IT IS BUILT: nixpkgs' stock yabai derivation (which compiles v7.1.25
# from source, aarch64 included) plus pkgs/yabai-master-center.patch. The
# patch is one commit, kept as a branch for rebasing:
#
#     ~/code/yabai                 clone of github.com/asmvik/yabai
#       branch master-center      = v7.1.25 + the layout commit
#
#   To update on a new upstream release: rebase master-center onto the new
#   tag, `make` to check it compiles, then
#     git format-patch -1 --stdout master-center > pkgs/yabai-master-center.patch
#   and bump/rebuild. If nixpkgs lags the release, the overlay arithmetic
#   still holds — the patch targets whatever src the derivation fetches, and
#   `git apply --check` against that tag is the pre-flight test.
#
# WHAT THE FORK TOUCHES (all in the one commit, ~230 lines):
#   * view.h/view.c — VIEW_MASTER_CENTER enum + view_master_center_update(),
#     which walks the leaves of the (otherwise untouched) bsp tree in order
#     and assigns each occupied leaf its frame directly. The tree is ONLY an
#     ordered container under this layout; splits and ratios are ignored.
#     view_add/remove_window_node re-run view_update themselves, mirroring
#     upstream's auto_balance pattern, so the batched (:AXBatching) flush
#     paths see final frames.
#   * message.c — parses `master_center` in `space --layout`, `config layout`
#     (global and --space), and adds `config center_ratio`.
#   * space_manager.{c,h} — center_ratio storage + live-refresh setter.
#   * window_manager.c — guard changes: warp/swap/insert/zoom-fullscreen now
#     ALLOWED on master_center; `--ratio` and zoom-parent REJECTED (they
#     consume internal-node areas, which this layout does not maintain).
#     `--resize` is accepted but a visual NO-OP on master_center spaces: it
#     ends in view_update, which reasserts canonical frames. Column sizes are
#     center_ratio's job, deliberately — fixed geometry is the point.
#
# STATUS: VERIFIED LIVE on 2026-08-19, macOS 26.6 arm64, SIP ENABLED, on the
# 5120x1440 ultrawide, driven by real window churn (spawned/killed Ghostty
# instances) rather than key presses. Measured, not inferred:
#
#   * THREE WINDOWS: 1274 | 2548 | 1274 at x=8/1286/3838, nothing floating —
#     PIXEL-EXACT quarters and half, better than the shell snap's 1275|2547|
#     1273, because frames are computed directly instead of through bsp
#     ratio rounding.
#   * SIX WINDOWS: slots 3|1|2, columns unchanged, left stack 3x462px and
#     right stack 2x695px with exact 4px gaps.
#   * SELF-MAINTAINING: every transition above happened on window create/
#     destroy alone — no keypress, no signals, no script.
#   * TEARDOWN HEALS: killing the three test windows returned the survivors
#     to exactly 1274 | 2548 | 1274.
#   * ONE WINDOW: centred 2548 at x=1286, BOTH quarters empty — the case
#     AeroSpace cannot express at all.
#   * TWO WINDOWS: 1274 @ x=8 + 2548 @ x=1286, right quarter EMPTY — the
#     layout this module exists for.
#   * center_ratio LIVE: 0.45 gave 1401 | 2293 | 1401 (2293 = 0.45 * 5096
#     exactly) in one reflow; 0.5 restored the original geometry.
#
# ALSO VERIFIED LIVE, same day, second session (all driven via the exact
# commands the keys run, plus real window churn):
#
#   * LAYOUT KEYS: stack (full-width 5104 at one origin, stack-index walks
#     with wrap 2->3->1), bsp (plain aspect-driven tiling, no reserved
#     quarter — correct), master_center restore, and the $mod+Y toggle in
#     both directions. The toggle's bsp case was THE ONE BUG this driving
#     session found — see the comment in layoutToggle.
#   * WARP BETWEEN SLOTS: columns hold canonical widths through every warp.
#     WHICH slot a warp lands in follows upstream's NaturalWarp distance
#     heuristic (message at window_manager.c :NaturalWarp), so a first
#     press can move within a column and a repeat press crosses into the
#     centre. Inherited bsp behaviour, not a layout bug; a deterministic
#     slot-swap warp would be a fork refinement if it grates.
#   * $modShift+Return: the next window JOINED the focused slot as a stack
#     (two windows sharing the centre at 2548px), and the columns counted
#     SLOTS, not windows — 5 windows, 4 slots, 2|1(x2)|1.
#   * MINIMISE: re-slotted to 2|1|1 while minimised; focusing the minimised
#     window restored and re-tiled it. Stack membership does NOT survive
#     minimise (yabai untiles on minimise — upstream behaviour).
#   * MONITORS, on the real two-display setup (ultrawide display 1 above,
#     built-in display 2 below): $modShift+U moved the window AND followed
#     focus; space 11 was already master_center and the lone window got the
#     exact centred half (w=744 on 1512px — the arithmetic holds on the
#     second geometry). $mod+U toggles both ways via the ||-fallback; the
#     arrows move south/north and correctly do nothing west/east; north
#     correctly fails at the top edge. ONE TRAP: `display --focus` onto an
#     EMPTY display does not stick — macOS keyboard focus snaps back to the
#     last focused window, so the query still reports the old display. With
#     any window present it works every time. Throw a window ($modShift+U)
#     rather than focusing an empty display.
#   * STALE QUERY ENTRIES STILL EXIST (lowercase app name, empty title,
#     has-ax-reference false) but are HARMLESS to this layout: an untiled
#     window is not a leaf, so it never counts toward the slots — the fork
#     structurally retired the COUNT-inflation bug the shell snap had to
#     filter around.
#
# Firefox's 500px floor is unchanged app behaviour and was not re-measured.
#
# ============================================================================
# WHY THIS EXISTS (unchanged). AeroSpace cannot express an empty slot: two
# tiled columns always divide their whole container, so "quarter | centred
# half | empty quarter" is unreachable without floating windows through the
# Accessibility API, which put the layout behind new windows and crashed
# AeroSpace via issue #1311. Stock yabai could only approximate it from
# outside — `space --layout` accepts exactly bsp|stack|float, there is no
# plugin/hook/custom-layout API, and signals fire only AFTER tiling decisions.
# The fork adds the layout at the only place it can exist: inside the engine.
# ============================================================================
#
# SIP AUDIT (unchanged, re-verify against upstream CHANGELOG on every bump —
# the SIP line has been MOVING, in the right direction: 7.1.19 returned
# `space --focus`, 7.1.25 `window --space`). Everything this module uses is
# on the safe side: padding, ratio, balance, equalize, layout, warp, swap,
# window --focus/--display/--space, space --focus. enableScriptingAddition
# stays false and SIP stays on. Current sources — upstream renamed
# koekeishiya -> asmvik, old links redirect:
#     https://github.com/asmvik/yabai
#     curl -sL https://raw.githubusercontent.com/asmvik/yabai/master/CHANGELOG.md
#
# WHAT THIS COSTS versus AeroSpace, priced honestly:
#
#   * WORKSPACES ARE NATIVE macOS SPACES — create all ten BY HAND in Mission
#     Control (`space --create` needs SIP off) and macOS renumbers them if
#     reordered.
#   * KEYBINDINGS LIVE IN skhd, a second daemon.
#   * ACCESSIBILITY IS GRANTED PER STORE PATH. Every yabai change — INCLUDING
#     EVERY EDIT TO THE PATCH — produces a new path and the grant must be
#     re-given in System Settings. This was already the single most annoying
#     ongoing cost; the fork makes it fire on layout changes too. Budget for
#     it on every iteration of the fork.
#   * "DISPLAYS HAVE SEPARATE SPACES" MUST BE ON (set declaratively below;
#     needs a log out; does NOT roll back — nix-darwin defaults are
#     write-only).
#
# BINDINGS THAT DO NOT PORT from AeroSpace (unchanged): $modShift+COMMA/
# PERIOD (move workspace to other monitor — `space --display` is SIP-gated),
# the $mod+SEMICOLON service mode (no flatten, no close-all), and $mod+Q
# closes a TAB in apps where ⌘W is tab-scoped.
#
# THE MAINTENANCE BET, updated for the fork: yabai is one maintainer who
# shipped nine releases Jan–May 2026 with a deliberate run at SIP-enabled
# operation. The fork raises the stake — every upstream release now costs a
# rebase (usually trivial: the patch touches stable seams) and macOS 27 lands
# late 2026 with its usual breakage risk. The exit that keeps the layout
# without the fork is upstreaming it; the exit that abandons ship is Amethyst
# (JS getFrameAssignments API — read from docs, never driven). Against that,
# the fork DELETED every recurring bug source this module had: the harness.
#
# KEY TIERS ARE UNCHANGED from aerospace.nix, so muscle memory transfers:
#
#   cmd + alt + ctrl           -> $mod        select / focus
#   cmd + alt + ctrl + shift   -> $mod SHIFT  move
#
# PUNCTUATION IS GIVEN AS HEX VIRTUAL KEYCODES (skhd's `-` separator
# collides): 0x1B minus, 0x18 equal, 0x2C slash, 0x29 semicolon, 0x2B comma,
# 0x2F period.
#
# THE RUNBOOK — bringing this up from scratch, or after the fork changes:
#
#   1. In modules/hosts/mac-work/default.nix set `windowManager = "yabai";`,
#      then `rebuildhm`. Never import this AND aerospace.
#   2. GRANT ACCESSIBILITY TO BOTH BINARIES by hand (System Settings ->
#      Privacy & Security; skhd may also need Input Monitoring). Point the
#      dialog at `readlink -f "$(which yabai)"` / `... skhd`. RE-DO THE yabai
#      GRANT AFTER EVERY PATCH EDIT — new store path, dead grant, and the
#      only symptom is a daemon that starts and manages nothing.
#   3. LOG OUT AND BACK IN (spans-displays, first setup only). If yabai seems
#      installed-but-dead, read /tmp/yabai_$USER.err.log — the launchd agent
#      now has a StandardErrorPath (set below), which the shell-snap era
#      lacked and badly missed. The classic message is
#      `yabai: 'display has separate spaces' is disabled! abort..`
#   4. CREATE THE TEN SPACES BY HAND in Mission Control. SPACE_SEL indices
#      are numbered ACROSS displays — check with
#        yabai -m query --spaces | jq '.[] | {index, display}'
#   5. VERIFY THE BASE CLAIMS, cheapest killer first:
#        yabai -m query --displays        # server answers
#        csrutil status                   # still enabled
#        yabai -m space --focus 2         # 7.1.19 claim
#        yabai -m window --space 2        # 7.1.25 claim
#   6. VERIFY THE FORK — none of this has been driven yet:
#        a. `yabai -m config layout` prints master_center (the default below).
#        b. One window on a fresh space: centred at half width, both quarters
#           empty, is-floating false:
#             yabai -m query --windows --space \
#               | jq -r '.[] | "\(.app) w=\(.frame.w) x=\(.frame.x) float=\(."is-floating")"'
#        c. Open windows up to eight. Column widths must hold (about
#           1275|2547|1273 on the ultrawide) with only the stacking changing:
#           1|1|1, 2|1|1, 2|1|2, 3|1|2, 3|1|3, 4|1|3. ODD counts are the ones
#           that catch ordering bugs.
#        d. Close back down to one. Every transition is ONE reflow, no
#           intermediate flashing — that is the fork's whole reason to exist;
#           if it flashes, something is calling flush before view_update.
#        e. $modShift+H/J/K/L a window between slots — layout holds, no keys
#           beyond the warp needed.
#        f. $mod+W (stack), open a window, $mod+I back — the three layouts
#           switch cleanly and legacy padding (from the shell-snap era, if
#           this machine ran it) is healed by the reset in the layout keys.
#        g. `yabai -m config center_ratio 0.45` — live one-pass reflow of
#           every master_center space; `0.5` puts it back.
#        h. Minimise + unminimise, cmd+H + reopen — yabai untiles/retiles
#           these itself now; the layout must follow with no extra machinery.
#   7. ROLLING BACK: windowManager = "aerospace" + rebuild. spans-displays
#      and the Ctrl+1..6 hotkey disables do NOT roll back (write-only
#      defaults); both are harmless under AeroSpace.
#
# TROUBLESHOOTING, in the order things have actually gone wrong:
#
#   * KEYS DO THE OLD THING, config provably right -> skhd serving its
#     boot-time parse. Structurally fixed below (mkForce plists the keymap by
#     store path), `skhd --reload` is the manual escape hatch.
#   * yabai DEAD, `failed to connect to socket` -> read /tmp/yabai_$USER.err.log
#     (StandardErrorPath below). Accessibility grant and spans-displays are
#     the usual suspects, in that order.
#   * A WINDOW WILL NOT SHRINK and the space stalls -> app minimum size
#     (Firefox: 500px — unusable as a side column on the 1512px built-in,
#     fine on the ultrawide). Put such windows in the master slot.
#   * NEW WINDOWS PILE UP WEIRDLY ON A bsp SPACE -> leftover per-space
#     padding from the shell-snap era. Any layout key heals it (they all
#     reset padding), or by hand: yabai -m space --padding abs:8:8:8:8
#   * skhd CRASH-LOOPING -> stale /tmp/skhd_$USER.pid from an orphan.
{ ... }:
{
  flake.modules.darwin.yabai =
    { config, lib, pkgs, ... }:
    let
      # Same gap sizes as aerospace.nix and hyprland.nix, so the machines feel
      # the same. The fork reads these from the standard padding/gap config —
      # the layout arithmetic lives in view_master_center_update now.
      gapInner = 4;
      gapOuter = 8;

      mod = "cmd + alt + ctrl";
      modShift = "cmd + alt + ctrl + shift";

      # THE FORK: stock nixpkgs yabai (builds v7.1.25 from source, aarch64
      # included) + the master_center commit. See the header for the rebase
      # pipeline. Everything in this module must use THIS package — a stock
      # client would still work for most commands, but `space --layout
      # master_center` would be rejected by string parse, and mixing store
      # paths doubles the Accessibility-grant churn.
      yabaiPkg = pkgs.yabai.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../pkgs/yabai-master-center.patch ];
      });

      # DIRECTIONAL FOCUS THAT ALSO WORKS IN A STACK, for $mod+H/J/K/L.
      #
      # A stacked space has no geometry to navigate — every window sits
      # full-screen at the same origin (measured: three windows all 1496x848
      # at x=8) — so `window --focus south` finds nothing and the only route
      # is `--focus stack.next|stack.prev`, a different command rather than a
      # different argument. All four keys dispatch on the space type so that
      # whichever axis you reach for pages the stack.
      #
      # THE WRAP MATTERS. Measured: stack.next fails at the end of the stack
      # ("could not locate the next stacked window"); the fallback to
      # stack.first/stack.last cycles instead — verified 1->2->3->1 both ways.
      #
      # master_center spaces take the bsp path: their leaves have real
      # geometry, so directional focus just works. Windows STACKED INTO ONE
      # SLOT (via $modShift+Return) page with `--focus stack.next` the same
      # as in a stack space — unhandled here; focus into the slot and yabai's
      # own directional focus picks the top of the stack.
      focusDir = pkgs.writeShellApplication {
        name = "yabai-focus-dir";
        runtimeInputs = [
          yabaiPkg
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
      # through this. The fork made the reset ALMOST vestigial — nothing sets
      # per-space padding any more — but it stays for two reasons: it heals
      # legacy padding left by the deleted shell snap on any space that ran
      # it (`space --padding` persists indefinitely), and it makes the layout
      # keys a full reset gesture, which is how they read.
      setLayout = name: layout: pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [ yabaiPkg ];
        text = ''
          yabai -m space --padding abs:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}
          yabai -m space --gap abs:${toString gapInner}
          ${layout}
        '';
      };

      toStack = setLayout "yabai-to-stack" "yabai -m space --layout stack";
      toBsp = setLayout "yabai-to-bsp" "yabai -m space --layout bsp";
      toCenter = setLayout "yabai-to-center" "yabai -m space --layout master_center";

      # master_center <-> stack as a genuine toggle, for $mod+Y — the daily
      # pair, matching aerospace.nix's tiles<->accordion. bsp is the odd one
      # out now, reachable only via $modShift+W; if a space is in bsp, $mod+Y
      # returns it to master_center.
      layoutToggle = pkgs.writeShellApplication {
        name = "yabai-layout-toggle";
        runtimeInputs = [
          yabaiPkg
          pkgs.jq
        ];
        text = ''
          yabai -m space --padding abs:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}:${toString gapOuter}
          yabai -m space --gap abs:${toString gapInner}
          # Keyed on master_center, NOT on stack: from bsp the toggle must
          # land on master_center (the daily layout), and a stack-keyed test
          # sent bsp to stack instead — measured live on 2026-08-19, the one
          # bug the first driving session found.
          CUR=$(yabai -m query --spaces --space | jq -r '.type')
          if [ "$CUR" = "master_center" ]; then
            yabai -m space --layout stack
          else
            yabai -m space --layout master_center
          fi
        '';
      };

      # A new Firefox WINDOW, for $mod+B. Identical mechanism to the AeroSpace
      # module's newWindow and for the same reasons — `open -b` only ACTIVATES
      # a running Firefox, `--args --new-window` is dropped when the app is
      # already up, and `open -n` starts a rival instance that fights over the
      # profile lock — so the binary is run directly and Firefox's own remote
      # protocol hands the request to the running instance. The workspace
      # carry from aerospace.nix is NOT ported; whether the teleport happens
      # under real Space switching is unverified (see aerospace.nix's
      # new_window_here if it does).
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
        # move that matches AeroSpace's `move` on a tree. Under master_center
        # the fork re-arranges INSIDE the warp — no appended re-snap, which is
        # what the shell-snap era needed here because window_moved cannot be
        # hooked.
        ++ lib.mapAttrsToList (
          k: d: bind modShift k "yabai -m window --warp ${d}"
        ) directions

        ++ [
          ""
          "# --- Workspaces (REAL macOS Spaces — create all ten by hand) -------"
          # SPACE_SEL takes a MISSION CONTROL INDEX, numbered across ALL
          # displays rather than per display — check what you actually got
          # with `yabai -m query --spaces | jq '.[] | {index, display}'`.
        ]
        ++ map (w: bind mod w.key "yabai -m space --focus ${w.index}") workspaces
        # Follow the window to its new Space. The follow is a TRAILING
        # `--focus` FLAG, not a `^` prefix — `^` is RULE syntax and SPACE_SEL
        # rejects it (measured: every key died with exit 1 in the draft that
        # used it). `--focus` here is undocumented but verified live.
        ++ map (w: bind modShift w.key "yabai -m window --space ${w.index} --focus") workspaces

        ++ [
          ""
          "# --- Monitors ------------------------------------------------------"
          # U toggles the focused display and $modShift+U throws the window
          # there. `next` does not wrap, so these fall back to `first`; with
          # two displays that is exactly a toggle. STILL UNVERIFIED live, as
          # are the arrows below.
          (bind mod "u" "yabai -m display --focus next || yabai -m display --focus first")
          (bind modShift "u" "yabai -m window --display next --focus || yabai -m window --display first --focus")

          # Explicit directions on the arrows. The physical arrangement is
          # VERTICAL — Dell U4924DW above, built-in below — so down = laptop
          # and up = ultrawide. No wrap, deliberately.
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
          # The centred master, on I where the deleted rectangle.nix kept its
          # centreHalf and where the shell snap lived. A plain layout set now:
          # the fork maintains the layout itself, so the key is only ever
          # needed to ENTER the layout (or heal legacy padding, via the reset
          # in setLayout).
          (bind mod "i" (lib.getExe toCenter))

          # Flip the split the focused window sits in — bsp spaces only; the
          # fork rejects it on master_center (fixed geometry is the point).
          (bind mod "0x2C" "yabai -m window --toggle split")

          # master_center <-> stack, the "switch the whole layout" gesture
          # ($mod+Y, matching aerospace's tiles<->accordion). W/shift+W are
          # the explicit setters, with bsp demoted to the shift tier as the
          # escape hatch back to plain tiling.
          (bind mod "y" (lib.getExe layoutToggle))
          (bind mod "w" (lib.getExe toStack))
          (bind modShift "w" (lib.getExe toBsp))

          # Reset the tree on a bsp space — no meaning under master_center
          # (the fork rejects balance there; geometry is not tree-derived).
          (bind modShift "0x2C" "yabai -m space --balance")

          ""
          "# --- Window state --------------------------------------------------"
          # $mod+F toggles float — the ONLY float anywhere in this module, and
          # entirely manual. The layout never floats anything; that is the
          # point of all of this.
          (bind mod "f" "yabai -m window --toggle float")
          # yabai's own zoom, not macOS native fullscreen: stays in the tree,
          # un-zooms cleanly. The fork allows this on master_center (the zoom
          # target is the view root, whose area IS maintained); zoom-parent
          # stays bsp-only (internal-node areas are not).
          (bind modShift "f" "yabai -m window --toggle zoom-fullscreen")
          # yabai has no close command — this is the standard macOS close
          # chord sent onward, and ⌘W is per-app: in Firefox it closes the
          # TAB. Less destructive than AeroSpace's real `close`; swap to
          # `cmd + shift - w` if window-close semantics matter more.
          (bind mod "q" "skhd -k 'cmd - w'")

          # DO NOT USE `yabai --restart-service` HERE — that drives yabai's
          # OWN plist (com.asmvik.yabai), not the nix-darwin agent, and at
          # worst starts a SECOND yabai. Address org.nixos.yabai directly.
          (bind modShift "r" "launchctl kickstart -k gui/$(id -u)/org.nixos.yabai")

          # $modShift+Return: arm the focused slot so the NEXT window JOINS IT
          # AS A STACK instead of taking a slot of its own — hy3:makegroup,
          # and the manual grouping gesture master_center is designed around
          # (a slot holds a stack; the column layout counts slots). This was
          # `--insert south` in the shell-snap era, where the direction
          # mattered to protect the centre; under the fork only `stack` is a
          # meaningful insert mode, since directions feed split decisions the
          # layout ignores.
          (bind modShift "return" "yabai -m window --insert stack")

          ""
          "# --- Resize --------------------------------------------------------"
          # bsp spaces only. On master_center the fork accepts these and then
          # reasserts canonical frames — a deliberate visual no-op; the column
          # widths are `config center_ratio`'s job.
          (bind mod "0x1B" "yabai -m window --resize right:-50:0")
          (bind mod "0x18" "yabai -m window --resize right:50:0")

          ""
          "# --- Launchers -----------------------------------------------------"
          # $mod Return -> ghostty and $mod B / $mod A -> browser, mirroring
          # both hyprland.nix and aerospace.nix. -n forces a new instance;
          # -a takes the app name because ghostty-bin is aliased into
          # /Applications/Nix Apps by the host. The Firefox "Work" container
          # launcher is deliberately not ported — see aerospace.nix's
          # workContainer for the graveyard of attempts.
          (bind mod "return" "open -na Ghostty")
          (bind mod "b" (lib.getExe newWindow))
          (bind mod "a" "open -b org.mozilla.firefox https://claude.ai")

          ""
          "# --- Misc ----------------------------------------------------------"
          # workspace-back-and-forth: SPACE_SEL includes `recent`, a
          # one-for-one port of AeroSpace's $mod+Tab.
          (bind mod "tab" "yabai -m space --focus recent")
          ""
        ]
      );
    in
    {
      # SIP STAYS ON. enableScriptingAddition would need `csrutil disable`
      # from recovery, and nothing this module uses — INCLUDING the fork's
      # layout, which lives entirely in the tiling pipeline — is on the far
      # side of that line. Stated explicitly so turning it on is a
      # deliberate, reviewable act.
      services.yabai = {
        enable = true;
        package = yabaiPkg;
        enableScriptingAddition = false;

        config = {
          # THE FORK'S LAYOUT IS THE DEFAULT. Every user space starts as (and
          # returns to, via $mod+I / $mod+Y) the centred master. bsp remains
          # reachable on $modShift+W.
          layout = "master_center";

          # The master's fraction of available width (fork-added; see the
          # header). 0.5 reproduces the shell-snap era's measured geometry;
          # hyprland.nix runs the same layout at mfact = 0.45.
          center_ratio = "0.5";

          # Gaps, matching aerospace.nix and hyprland.nix.
          top_padding = gapOuter;
          bottom_padding = gapOuter;
          left_padding = gapOuter;
          right_padding = gapOuter;
          window_gap = gapInner;

          # Off, matching aerospace.nix's focus-follows-mouse.enabled = false.
          # Flip to "autoraise" for Hyprland parity (input.follow_mouse = 1).
          focus_follows_mouse = "off";
          # The analogue of aerospace.nix's on-focused-monitor-changed =
          # move-mouse monitor-lazy-center.
          mouse_follows_focus = "on";

          # New windows become the second child — they open after the window
          # they split rather than displacing it. Under master_center this is
          # what makes a new window take the NEXT slot after the focused one
          # (leaf order is slot order).
          window_placement = "second_child";
          split_ratio = 0.5;
          # Off: auto_balance re-equalises bsp ratios on every open/close.
          # Irrelevant to master_center (which ignores ratios) but it would
          # still churn bsp spaces.
          auto_balance = "off";

          # fn as the drag modifier keeps the mouse bindings off the four-
          # modifier tiers above.
          mouse_modifier = "fn";
          mouse_action1 = "move";
          mouse_action2 = "resize";
          mouse_drop_action = "swap";

          # Everything below needs the scripting addition and is left at its
          # inert value ON PURPOSE — with SIP enabled yabai ignores or errors
          # on them.
          window_shadow = "on";
          window_opacity = "off";
        };
      };

      # THE ERROR LOG THE SHELL-SNAP ERA WISHED FOR. Without it, a yabai that
      # aborts at startup (spans-displays off, dead Accessibility grant after
      # a store-path change — i.e. after every patch edit) is invisible: the
      # agent sits at `spawn scheduled` and every command says `failed to
      # connect to socket`. Now the reason is one cat away.
      launchd.user.agents.yabai.serviceConfig.StandardErrorPath =
        "/tmp/yabai_jevin.err.log";
      launchd.user.agents.yabai.serviceConfig.StandardOutPath =
        "/tmp/yabai_jevin.out.log";

      # A HARD REQUIREMENT, not a preference: yabai aborts at startup without
      # it. THE POLARITY IS INVERTED relative to the UI — this key is "one
      # space SPANS all displays", so false means "Displays have separate
      # Spaces" CHECKED. Needs a log out (the window server reads it at
      # session start) and does NOT roll back (nix-darwin defaults are
      # write-only); to undo by hand:
      #   defaults write com.apple.spaces spans-displays -bool true
      system.defaults.spaces.spans-displays = false;

      # yabai has no hotkeys of its own, so skhd is not optional here.
      services.skhd = {
        enable = true;
        skhdConfig = keymap;
      };

      # MAKE THE skhd AGENT'S PLIST DEPEND ON THE KEYMAP — the whole fix for
      # "the config is correct but the keys do the old thing".
      #
      # skhd parses its config ONCE, at startup, and nix-darwin reloads an
      # agent only when its PLIST changes. Upstream points skhd at
      # /etc/skhdrc — a stable path, so the plist never changes and edits
      # never land (observed live: a provably-correct /etc/skhdrc while the
      # keys ran a previous build). Pointing -c at a store path adopts the
      # yabai module's behaviour: keymap edit -> new store path -> plist
      # differs -> nix-darwin unload/load -> skhd re-reads. services.skhd
      # stays enabled so /etc/skhdrc is still written — it is the obvious
      # place to inspect the live keymap, and an empty skhdConfig would drop
      # -c entirely.
      launchd.user.agents.skhd.serviceConfig.ProgramArguments = lib.mkForce [
        "${config.services.skhd.package}/bin/skhd"
        "-c"
        "${pkgs.writeText "skhdrc" keymap}"
      ];

      # DISABLE macOS'S OWN Ctrl+1..6 DESKTOP SWITCHING, so the meh key
      # (⌃⌥⌘ + 1..0) is the only way to change workspace. These were bound by
      # the retired darwin.macSpaces module and nix-darwin defaults are
      # write-only, so they were still live years later (measured: ids
      # 118..123 enabled with modifier 262144 on keys 1..6).
      #
      # `-dict-add` IS LOAD-BEARING: it merges into AppleSymbolicHotKeys. Do
      # NOT `defaults delete` or plain-write the whole dict — that wipes
      # EVERY system hotkey. The full `value` dict is restated because
      # -dict-add replaces the entry wholesale; dropping `value` would show
      # the shortcut as unassigned rather than unchecked.
      #
      # LIKE spans-displays, THIS DOES NOT ROLL BACK. Restore via System
      # Settings -> Keyboard -> Shortcuts -> Mission Control ->
      # "Restore Defaults".
      system.activationScripts.postActivation.text =
        let
          user = config.system.primaryUser;
          # id, ASCII of the digit, virtual keycode. Note 5 and 6 are keycodes
          # 23 and 22 — NOT sequential, which is why these are listed rather
          # than computed.
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

          # NO EXPLICIT skhd RELOAD HERE, deliberately — the mkForce'd plist
          # above makes nix-darwin's own activation do the reload when the
          # keymap changes. A belt-and-braces step that never fires is
          # indistinguishable from one that does not work.
        '';

      # yabai must be pickable in the Accessibility dialog, and the Nix Apps
      # aliaser only covers .app bundles — yabai is a bare binary, so the
      # dialog is pointed at its store path by hand (`readlink -f $(which
      # yabai)`). Listing the FORK here keeps `which yabai` resolving to the
      # same binary the agent runs; the grant still dies on every version or
      # patch bump.
      environment.systemPackages = [ yabaiPkg ];
    };
}
