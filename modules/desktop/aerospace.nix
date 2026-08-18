# AeroSpace — tiling window manager for macOS. The mac-work analogue of hy3
# on the Hyprland hosts, and the replacement for Rectangle.
#
# WHY THIS REPLACED RECTANGLE. Rectangle snapped the focused window into a
# screen region and nothing else: no tree, no retile when a window closes, no
# workspaces, and — the real limitation — no way to change *which* window is
# focused. That forced the job across three tools (Rectangle for layout, AltTab
# for selection, and a mac-spaces module that bound Ctrl+1..6 to Mission
# Control Desktops). AeroSpace does layout, directional focus and workspaces
# itself, so both of those modules are gone; only AltTab remains, and for a
# different job (see modules/desktop/alt-tab.nix).
#
# WHY AEROSPACE NEEDS NO SIP CHANGES: it does not drive Mission Control at all.
# It emulates workspaces by parking windows off-screen instead, so it needs only
# Accessibility. See AEROSPACE WORKSPACES ARE NOT macOS SPACES below for the
# consequences of that design.
#
# THE FLOAT-BASED SNAP THAT USED TO LIVE HERE IS GONE. It floated windows and
# set their frames through the Accessibility API to build a 25/50/25 for one and
# two window counts, because AeroSpace cannot tile an empty slot. It crashed
# AeroSpace outright, and reliably:
#
#   AppBundle.MacWindow is already unbound
#     FocusCommand.run -> makeFloatingWindowsSeenAsTiling -> unbindFromParent
#     refreshSessionEvent: socketServer: focus --window-id <id>
#
# That is upstream https://github.com/nikitabobko/AeroSpace/issues/1311,
# "Crash 'AppBundle.MacWindow is already unbound'. `focus` command over floating
# windows" — filed 2025-04-16, labelled bug/regression/crash, STILL OPEN as of
# 2026-08. The snap ended with `aerospace focus --window-id "$CENTRE"` on a
# window it had just floated, which is exactly the reported trigger. Observed
# here: /private/tmp/bobko.aerospace/aerospace-runtime-error.txt with die: true,
# the launchd agent at runs = 4, and every window re-tiled to equal columns
# because the tree was rebuilt from scratch.
#
# The float approach was ALSO wrong independently of the crash. A floated window
# is not a tiling sibling, so the next window to appear tiles alone at full
# width IN FRONT of it — the layout vanishes behind a window that thinks it is
# the only one. A companion script (dissolveSnap) put the floats back in the
# tree from the on-window-detected callback, but it could only fire when the
# floats were the ONLY other windows on the workspace; with anything else open
# it correctly refused, and the layout got buried. So the mechanism could not be
# made correct, only narrowed.
#
# DO NOT REINTRODUCE FLOATS TO GET AN EMPTY SLOT. Two tiled columns always
# divide their whole container, and AeroSpace has no placeholder node, so
# "quarter, centred half, empty quarter" is not expressible in its tiling model.
# The three-window branch below survives because it uses `resize` on tiled
# windows and never floats anything.
#
# YABAI IS THE STANDING ALTERNATIVE, and the reason is exactly the primitive
# above. The retired yabai/skhd config is still in
# modules/apps/desktop-mac.nix (dormant, packages commented out). Its skhdrc
# carries the note that killed it:
#
#   # Turned off in favor for Hammerspoon as it doesn't need disabling of
#   # MacOS security
#
# THAT NOTE IS WRONG FOR MODERN YABAI. Verified against yabai's own man page
# (doc/yabai.asciidoc), which carries the sentence "System Integrity Protection
# must be partially disabled" on individual commands rather than globally. With
# SIP FULLY ENABLED yabai gives tiling, `window --ratio abs:<r>` (real tiled
# split ratios), `space --padding` (which is how an empty slot is expressed
# without floating anything), `space --balance/--mirror/--rotate/--layout`,
# `window --grid/--warp/--swap`, `space --focus` (since 7.1.19, 2026-04-18) and
# `window --space` (since 7.1.25, 2026-05-08). What still needs SIP partially
# disabled: opacity/shadow/animation, `window --raise/--lower/--sub-layer`,
# `--toggle sticky|pip`, scratchpads, and space create/destroy/move/swap/display.
# None of that is load-bearing here.
#
# nix-darwin has services.yabai (config / extraConfig / package /
# enableScriptingAddition, which defaults to false), so it would be as
# declarative as this file. The costs are real and should be priced before any
# move: workspaces become native macOS Spaces, created by hand, with no
# persistent-workspaces equivalent; keybindings move to skhd; and z-order
# control is on the far side of the SIP line.
#
# The risks, recorded so they are not rediscovered: yabai is one maintainer (the
# GitHub account renamed koekeishiya -> asmvik, same person) who publicly asked
# in Oct 2025 whether anyone still used the project, then shipped nine releases
# between Jan and May 2026 — including a deliberate run at making things work
# with SIP enabled. Tahoe support is self-described as "preliminary" (7.1.16).
# macOS 27 lands late 2026 and every macOS major has historically broken
# something. Against that, AeroSpace is pushed to more often but has left the
# crash above open for sixteen months.
#
# AMETHYST was the other candidate and is still a bad trade: a real three-column
# layout with a main-pane ratio that self-maintains, needing only Accessibility,
# but no workspace model to replace AeroSpace's and a plist rather than anything
# Nix-shaped. Trading workspaces for a ratio is not worth it.
#
# PER-MONITOR OUTER GAPS deserve a mention because AeroSpace supports them
# declaratively, e.g. gaps.outer.left = [{ monitor.dell = 1274 }, 8]. Zero
# script, no Accessibility, and a lone window is natively centred at the master
# width — but it caps the ENTIRE tiling area at that width, so the three-column
# case dies. Only sensible if the ultrawide's outer thirds are wasted anyway.
#
# AEROSPACE WORKSPACES ARE NOT macOS SPACES. This is the consequence of that
# design and the thing most likely to surprise. An AeroSpace workspace is a set
# of windows it parks off-screen, so:
#   * Mission Control still shows whatever native Spaces you created by hand.
#     Those are untouched by anything here.
#   * macOS native fullscreen creates a real Space, which AeroSpace cannot
#     manage. `fullscreen` below is AeroSpace's own; the native one is the
#     separate macos-native-fullscreen command.
#
# The retired mac-spaces module drove those native Spaces from Ctrl+1..6 by
# writing AppleSymbolicHotKeys ids 118..123. Deleting it does NOT unwrite them —
# nix-darwin's system.defaults are write-only, with no rollback — so if those
# binds are still live and unwanted, clear them in System Settings → Keyboard →
# Keyboard Shortcuts → Mission Control ("Restore Defaults" there is safe;
# `defaults delete com.apple.symbolichotkeys AppleSymbolicHotKeys` is NOT, as it
# would wipe every system hotkey, not just those six).
#
# KEY TIERS. Exactly the split the deleted rectangle.nix reserved and could not
# fill, mirroring hyprland.nix where $mod selects and $mod+SHIFT moves:
#
#   ctrl+option+command        → $mod        select / focus
#   ctrl+option+shift+command  → $mod SHIFT  move
#
# ⌃⌥⌘ is not an arbitrary pick: the keyboard on this machine has a single
# physical key that expands to exactly that set. Verified in
# Karabiner-EventViewer (see modules/desktop/key-inspect.nix) — one press emits
# left_command, then left_option, then left_control, in that fixed order, with
# the same order on release, and emits NO key_code of its own. That last part is
# what makes it usable here: a layout key that also sent a regular key code
# could not serve as a modifier tier.
#
# It is the same gesture the retired skhd config called `cmd + alt + ctrl`, so
# the muscle memory from that era transfers unchanged.
#
# CAUTION on the name. This key gets called "meh" locally, but canonical Meh is
# ⌃⌥⇧ (no command) and canonical Hyper is ⌃⌥⌘⇧. This one is ⌃⌥⌘ — Hyper minus
# Shift, matching neither. If the key is ever regenerated from a keyboard's
# built-in "Meh" preset it will start sending ⌃⌥⇧ and every binding below will
# stop matching. Re-check in EventViewer before blaming this file.
#
# AeroSpace's notation has no left/right modifier variants — the shipped
# default-config.toml gives the complete list as cmd, alt, ctrl, shift — so
# these binds match the left-hand keys the layout actually sends.
#
# The plain option tier is deliberately untouched: AltTab holds ⌥Tab
# (modules/desktop/alt-tab.nix), and AeroSpace's own default config puts
# everything on bare `alt`, which would collide. Bare command is unusable for
# these binds anyway — ⌘H hides the app and ⌘L/⌘J/⌘K are claimed by nearly
# every app — which is why Super→Command is not a safe translation of the
# Hyprland keys and this stack of four modifiers exists instead. Caps Lock is
# remapped to Control on this host (system.keyboard in the mac-work host), so
# the ctrl in that stack is on the home row.
#
# WHY A DARWIN MODULE, NOT HOME-MANAGER. home-manager has no aerospace module;
# nix-darwin's services.aerospace is the only one, and it manages the launchd
# agent (KeepAlive + RunAtLoad) rather than AeroSpace's own start-at-login —
# which is why start-at-login must stay false, and is asserted upstream.
#
# It also adds the package to environment.systemPackages itself, so AeroSpace
# lands in /Applications/Nix Apps via the nix-darwin aliaser with no extra entry
# in the host. That matters: AeroSpace needs Accessibility permission granted
# once by hand (System Settings → Privacy & Security → Accessibility), and the
# permission dialog can only pick an app LaunchServices will index — which is
# the whole reason AltTab is listed in the host's environment.systemPackages.
# Nix cannot grant it.
#
# NO home.file / defaults DANCE. Unlike alt-tab.nix, which has to push its
# preferences through `defaults` because cfprefsd will not follow symlinks into
# the Nix store (see that module's header), AeroSpace reads a plain TOML file
# passed on the command line (--config-path). So the config is generated
# natively with pkgs.formats.toml from the attrs below — no plist, no
# activation script, no cfprefsd cache to bust.
#
# VALIDATING A CHANGE. `reload-config --dry-run` is a client command and needs
# the agent already running, so it is a post-rebuild check, not a pre-flight
# one. After `rebuildhm`:
#
#   aerospace reload-config --dry-run --warnings-as-errors
#
# The launchd agent pins --config-path to a store path, so the running instance
# only picks up changes on rebuild. auto-reload-config is therefore left off:
# it watches the config file, and this one is immutable.
#
# config-version = 2 is required for persistent-workspaces. It is not a
# declared option in the nix-darwin module, but settings has a freeform TOML
# type, so it passes straight through.
{ ... }:
{
  flake.modules.darwin.aerospace =
    { config, lib, pkgs, ... }:
    let
      mod = "ctrl-alt-cmd";
      modShift = "ctrl-alt-shift-cmd";

      # Gap sizes, matching gaps_in / gaps_out in hyprland.nix. Declared here
      # rather than inline in settings.gaps because centerMaster below has to do
      # arithmetic with them — the available width for windows is the monitor
      # minus the two outer gaps minus the inner gaps between them.
      gapInner = 4;
      gapOuter = 8;

      # THE CENTRED-MASTER SNAP: 1/4 | 1/2 | 1/4, the arrangement
      # hyprland.nix gets from `master` with orientation = center and
      # mfact = 0.45.
      #
      # AeroSpace has NO master layout and no split-ratio setting. Its layouts
      # are only tiles and accordion; the target-layout vocabulary is exactly
      # tiles / accordion / horizontal / vertical / h_tiles / v_tiles /
      # h_accordion / v_accordion / floating / tiling, with nothing resembling
      # mfact, split_ratio or a master area. Internally nodes do carry a
      # `weight`, but the only thing that can change it is the `resize` command
      # — there is no way to declare it in the config. So this ratio cannot be a
      # layout you switch to; it has to be applied to the windows you have.
      #
      # CONSEQUENCE, and the honest limitation: this does NOT self-maintain.
      # hyprland's master layout keeps the ratio as windows come and go, sending
      # new windows to the slave stacks. AeroSpace re-tiles to equal widths, so
      # opening or closing a window flattens the 25/50/25 back to thirds and the
      # key has to be pressed again. There is no config option that changes
      # this.
      #
      # WINDOW COUNTS. This key needs THREE tiled windows, and only three:
      #
      #   3  the case this exists for: shrink the centre to AVAIL/2, and the
      #      sides fall out equal at AVAIL/4 each (see the resize note below)
      #   2  two tiled columns are already AVAIL/2 each — which IS the centre
      #      width — so balance-sizes alone is the whole job. The right slot
      #      cannot be left empty: tiling divides the entire container, and
      #      AeroSpace has no placeholder node. See the header on why the float
      #      hack that used to fake this is gone and must not come back.
      #   1  a lone window fills the monitor. `resize width N` EXITS 2 AND DOES
      #      NOTHING, silently, with no error message at all — resize spreads
      #      its delta across siblings and a lone window has none, so there is
      #      nothing to take the space. Measured on 0.21.2-Beta. There is no
      #      tiling route to a narrow single window, and the non-tiling route
      #      crashed AeroSpace (see the header).
      #
      # NOTHING HERE WRITES WINDOW GEOMETRY ANY MORE. The only osascript calls
      # left are `display notification` and the read-only NSScreen width lookup
      # below, neither of which is Accessibility-gated, so this script needs no
      # TCC grant of its own.
      #
      # Worth keeping from the era that did: TCC ATTRIBUTES A REQUEST TO THE
      # RESPONSIBLE PROCESS, not to the executable. The same AX read fails from
      # launchd with "osascript is not allowed assistive access. (-1719)" and
      # succeeds when spawned by AeroSpace, which already holds Accessibility.
      # So a script AeroSpace launches with exec-and-forget inherits the grant,
      # and a per-executable grant for /usr/bin/osascript is not the fix if
      # something here ever appears to be permission-blocked.
      #
      # HOW IT ORDERS THE WINDOWS. By walking AeroSpace's own tree, not by
      # reading geometry. `focus --boundaries workspace --boundaries-action fail`
      # exits non-zero at the edge of the workspace, which gives a terminating
      # walk: step left until it fails to find the leftmost window, then step
      # right collecting window ids to get them in visual order.
      #
      # DO NOT reimplement this with CGWindowList, which is what this script
      # first did and which is broken. CGWindowList with kCGWindowListOption-
      # OnScreenOnly omits windows macOS considers occluded, so a live test
      # against six tiled windows returned only three positions. The join then
      # silently dropped the windows it could not place, mistook six windows for
      # three, and resized the wrong two. AeroSpace's tree is the only reliable
      # source for what is tiled and in what order.
      #
      # HOW THE THREE-WINDOW BRANCH FINDS THE WIDTH. AeroSpace reports no
      # dimensions at all —
      # list-monitors offers only monitor-id / monitor-name /
      # monitor-appkit-nsscreen-screens-id, and list-windows only window-id /
      # window-title / workspace. But that third monitor field is the monitor's
      # index into AppKit's NSScreen.screens (1-based), so the width can be read
      # from NSScreen via the JXA Objective-C bridge — exactly, for the focused
      # monitor, with no compiled helper and no cursor-position guessing.
      # Verified live: monitor 1 "Dell U4924DW" → NSScreen index 0, width 5120;
      # monitor 2 "Built-in Retina Display" → index 1, width 1512.
      #
      # visibleFrame is the right field: it already excludes the menu bar, and
      # AeroSpace applies its outer gaps inside it. On the 5120 ultrawide the
      # available width is 5120 - 8 - 8 - 4 - 4 = 5096, so the sides land at
      # 1274 and the centre keeps 2548. `resize width` was confirmed against a
      # live session to take absolute points, to be addressable by --window-id,
      # and to be undone cleanly by balance-sizes.
      centerMaster = pkgs.writeShellApplication {
        name = "aerospace-center-master";
        runtimeInputs = [ pkgs.aerospace ];
        text = ''
          OUTER=${toString gapOuter}
          INNER=${toString gapInner}

          notify() {
            /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" \
              >/dev/null 2>&1 || true
          }

          focused_id() { aerospace list-windows --focused --format '%{window-id}'; }

          # RESIDUAL EXPOSURE TO UPSTREAM #1311, stated because it is not zero.
          # The crash lives in makeFloatingWindowsSeenAsTiling, which AeroSpace
          # runs from FocusCommand whenever the workspace holds ANY floating
          # window — so every `focus` below, including the walk and the final
          # one, is exposed while a float is present. --ignore-floating changes
          # which window is chosen, not whether that routine runs.
          #
          # What removing the snap's floats bought is that this config no longer
          # MANUFACTURES the trigger on a keypress. A window floated by hand with
          # mod+F still leaves a window of risk, and there is no way to close it
          # from here: AeroSpace offers no focus that skips the reconciliation.

          # One step left or right, non-zero at the workspace edge so the walks
          # below terminate. --ignore-floating keeps floating windows out.
          step() {
            aerospace focus --ignore-floating \
              --boundaries workspace --boundaries-action fail "$1" >/dev/null 2>&1
          }

          # Window count INCLUDING floating ones. The walk below counts only
          # tiled windows, so this is what lets the failure message name a
          # float that is in the way instead of reporting a bare tiled count.
          WS=$(aerospace list-workspaces --focused)
          TOTAL=$(aerospace list-windows --workspace "$WS" \
                    --format '%{window-id}' | grep -c . || true)

          # Columns, not rows, whatever the workspace was in before. Do this
          # before the walk so left/right mean what they look like.
          aerospace layout --root h_tiles >/dev/null 2>&1 || true
          aerospace balance-sizes

          # Walk to the leftmost window, then rightwards collecting ids in
          # visual order. MAXWALK only guards against a pathological tree
          # keeping the loop alive; a normal workspace exits far sooner.
          MAXWALK=64
          i=0
          while [ "$i" -lt "$MAXWALK" ] && step left; do i=$((i + 1)); done

          ordered=$(focused_id)
          count=1
          i=0
          while [ "$i" -lt "$MAXWALK" ] && step right; do
            ordered="$ordered
          $(focused_id)"
            count=$((count + 1))
            i=$((i + 1))
          done

          # --- TWO TILED: balance-sizes above already did the whole job ------
          # Two tiled columns each get AVAIL/2, which is exactly the centre
          # width, so there is nothing left to resize. Silent rather than a
          # notify: this is a success, not a refusal.
          if [ "$count" -eq 2 ]; then
            exit 0
          fi

          if [ "$count" -ne 3 ]; then
            # Name the actual obstacle. A float that someone put there by hand
            # with mod+F is the usual reason the tiled count is lower than the
            # workspace looks.
            stray=$((TOTAL - count))
            if [ "$stray" -gt 0 ]; then
              notify "Centred master" \
                "$stray floating window(s) in the way — mod+F un-floats"
            else
              notify "Centred master" "Needs 2 or 3 tiled windows (found $count)"
            fi
            exit 0
          fi

          center=$(printf '%s\n' "$ordered" | sed -n 2p | tr -d '[:space:]')

          # Width of the focused monitor, via its NSScreen index (1-based).
          # Read here rather than up front because only this branch needs it, so
          # an unreadable NSScreen cannot fail a press that would have worked.
          idx=$(aerospace list-monitors --focused \
                  --format '%{monitor-appkit-nsscreen-screens-id}')
          # Returns 0 rather than an empty string on a bad index. An empty
          # single-quoted JS string cannot be written here at all: a doubled
          # apostrophe terminates the surrounding Nix indented string, so even
          # mentioning one in a comment breaks the build.
          MON_W=$(/usr/bin/osascript -l JavaScript -e "
            ObjC.import('AppKit');
            const ss = $.NSScreen.screens, i = $idx - 1;
            (i >= 0 && i < ss.count)
              ? Math.round(ss.objectAtIndex(i).visibleFrame.size.width) : 0;
          ")

          if [ -z "$MON_W" ] || [ "$MON_W" -le 0 ]; then
            notify "Centred master" "Could not read the focused monitor width"
            exit 1
          fi

          AVAIL=$((MON_W - 2 * OUTER - 2 * INNER))

          # ONE resize, on the CENTRE, immediately after balance-sizes. That
          # ordering is what makes the sides come out equal without ever being
          # touched: `resize` spreads its delta across all siblings, so shrinking
          # the two equal side windows by the same amount leaves them equal, and
          # the fixed total forces each to AVAIL/4.
          #
          # DO NOT set the sides instead and let the centre take the remainder.
          # That was the first version, and it does not converge: setting the
          # left window perturbs the right and vice versa, so each pass only
          # halves the error. Measured on the ultrawide with a 1274 target, two
          # passes left the sides at 1352 and 1272 — visibly lopsided. Setting
          # the centre once gave 1276 | 2544 | 1276, symmetric and within a
          # couple of points, the residue being AeroSpace's own weight rounding.
          aerospace resize --window-id "$center" width $((AVAIL / 2))

          aerospace focus --window-id "$center"
        '';
      };

      # A new Firefox WINDOW, for $mod+B — matching hyprland, where
      # `exec, firefox` gives a window rather than a tab.
      #
      # WHY NOT `open`. `open -b org.mozilla.firefox` only ACTIVATES a running
      # Firefox, so $mod+B did nothing visible once the app was up. Adding
      # `--args --new-window` does not help either: macOS passes --args only when
      # it actually launches the app, and silently drops them when it is already
      # running (verified live — window count stayed at 2). And `open -n` is the
      # wrong tool: that starts a second INSTANCE, which fights the first over
      # the profile lock.
      #
      # Running the binary directly is what works, because Firefox's own remote
      # protocol hands the request to the running instance — the same mechanism
      # that makes plain `firefox` open a window on Linux. Verified live: window
      # count 4 -> 5.
      #
      # The path is resolved through LaunchServices from the BUNDLE ID rather
      # than hardcoded, for the reason the $mod+B bind already documents below:
      # Firefox is hand-installed in /Applications and nothing in this repo
      # manages it, so its filename is not guaranteed. `path to application id`
      # is not Accessibility-gated, so neither of these scripts needs a TCC grant.
      #
      # Shared by newWindow and workContainer; sets $FIREFOX and defines
      # new_window_here. $APP carries a trailing slash, so the path doubles a
      # separator — harmless on POSIX, and stripping it would need a shell
      # parameter expansion whose brace form has to be escaped inside a Nix
      # indented string. Not worth it.
      #
      # WHY new_window_here EXISTS, i.e. why this is not just one exec line.
      # `firefox --new-window` ACTIVATES Firefox, and activating an app raises
      # its most recently used window — which is very often parked on another
      # workspace. AeroSpace follows that focus, switches to that workspace, and
      # only then detects the new window, so the window is born over there. The
      # keypress therefore teleports you instead of giving you a browser beside
      # what you were doing. Measured live: focused workspace 1, run the script,
      # end up on workspace 2 with the new window on 2.
      #
      # So the workspace is read BEFORE the launch and the window is carried
      # back. Verified: the window lands on the original workspace and tiles
      # with what was already there.
      #
      # THE WINDOW IS FOUND BY DIFFING window ids, not by asking for Firefox's
      # focused window. `list-windows --focused` is unreliable here — focus is
      # in motion for a moment after activation — and the newest id is not
      # necessarily the largest. A snapshot before and after is exact.
      firefoxLib = ''
        APP=$(/usr/bin/osascript -e \
          'POSIX path of (path to application id "org.mozilla.firefox")')
        FIREFOX="$APP/Contents/MacOS/firefox"

        new_window_here() {
          local ws before new
          ws=$(aerospace list-workspaces --focused)
          before=$(aerospace list-windows --all --format '%{window-id}')

          "$FIREFOX" --new-window "$@"

          # ~5s of polling. Firefox answers in well under a second when it is
          # already running; a cold start is what needs the headroom.
          new=""
          for _ in $(seq 1 50); do
            new=$(aerospace list-windows --all --format '%{window-id}' \
                    | grep -vxF "$before" | head -1 || true)
            if [ -n "$new" ]; then break; fi
            sleep 0.1
          done

          # No window appeared — nothing to place, and Firefox has already said
          # whatever it had to say. Leave the workspace as the launch left it.
          [ -n "$new" ] || return 0

          # Each of these no-ops when it is already true (the window was born
          # here, the workspace never changed), and a no-op only prints a tip
          # unless --fail-if-noop is passed.
          aerospace move-node-to-workspace --window-id "$new" "$ws" >/dev/null || true
          aerospace workspace "$ws" >/dev/null || true

          aerospace focus --window-id "$new" >/dev/null || true
        }
      '';

      newWindow = pkgs.writeShellApplication {
        name = "firefox-new-window";
        runtimeInputs = [ pkgs.aerospace ];
        text = ''
          ${firefoxLib}
          new_window_here about:newtab
        '';
      };

      # A new Firefox WINDOW in the "Work" container, for $modShift+B — so Shift
      # means "the work variant of the browser" the same way it means "the move
      # variant" elsewhere in this keymap. Only two containers are in use here,
      # the default/no-container one ($mod+B above) and Work.
      #
      # HOW IT WORKS: a plain --new-window on a work URL, which Mozilla's
      # Multi-Account Containers extension REASSIGNS into the Work container
      # because the site is assigned to it. So nothing here mentions containers
      # at all — the container comes from the extension's site assignment, which
      # is the only mechanism that survives being invoked from outside Firefox.
      #
      # SETUP, by hand, once (Firefox is not managed by this repo):
      #   1. Install Multi-Account Containers.
      #   2. Open workUrl below, open the extension's panel, and set
      #      "Always open this site in Work".
      #   3. If it then shows a confirmation page on each open, disable that
      #      prompt for the assignment.
      # The extension adopts the existing containers.json rather than creating
      # containers — verified live: tyvi1dnz.default-release holds exactly
      # Personal userContextId=1 and Work userContextId=2 with l10nId
      # user-context-work, stock Banking/Shopping deleted.
      #
      # EVERY OTHER ROUTE WAS TRIED AND MEASURED. Do not re-litigate these:
      #
      #   * No CLI flag exists. `firefox --help` offers -P/--profile,
      #     --new-window and --private-window; nothing sets a userContextId.
      #     Containers are cookie jars INSIDE a profile, so -P cannot reach them.
      #   * `ext+container:name=Work&url=...` DOES NOT WORK, and not merely from
      #     the CLI: Multi-Account Containers 8.3.8 ships
      #     `protocol_handlers: null`, so nothing registers that scheme. Firefox
      #     treated the URL as a search term via both the command line and the
      #     `open`/Apple Event path. Earlier revisions of this comment claimed
      #     otherwise and were wrong.
      #   * The File > New Container Tab menu click works and lands in the
      #     focused window (AeroSpace does focus a freshly created window —
      #     confirmed via AXFocusedWindow), but it yields a TAB beside a blank
      #     one, and the blank cannot be closed: Cmd-1 does not move tab focus
      #     (a live run closed the Work tab instead), keystrokes do not reach
      #     Firefox reliably, and "move tab to new window" exists only in the tab
      #     context menu, not the menu bar. It also needs a broad Accessibility
      #     grant for /usr/bin/osascript, since TCC is per-executable and
      #     exec-and-forget spawns osascript as a child of AeroSpace.
      #   * MAC's own open_container_N commands (Ctrl+Shift+2 is Work here, index
      #     1) work fine BY HAND inside Firefox, but reaching them from a keybind
      #     would mean synthesising keystrokes, i.e. the same dead end.
      #
      # Note the session store cannot be used to verify any of this: Firefox does
      # not persist blank tabs or blank windows, so a container tab showing
      # about:blank never appears in recovery.jsonlz4. Verify with a real URL.
      #
      # workUrl must NOT be the homepage that $mod+B lands on
      # (https://homepage.jevy.org): assignment is per-site, so assigning the
      # homepage to Work would drag the personal window into the Work container
      # too. This defaults to the work GitHub the machine was already using;
      # change it to whatever the real work start page is.
      workUrl = "https://github.com/covenantco/covenant-web/pulls";
      workContainer = pkgs.writeShellApplication {
        name = "firefox-work-container";
        runtimeInputs = [ pkgs.aerospace ];
        text = ''
          notify() {
            /usr/bin/osascript -e "display notification \"$2\" with title \"$1\"" \
              >/dev/null 2>&1 || true
          }

          # Fail with a readable message rather than Firefox's unhelpful
          # "address wasn't understood" page when the extension is absent. Only
          # warns when the profile tree is positively known to lack it — if the
          # layout is unexpected, proceed rather than block a working setup.
          PROFILES="$HOME/Library/Application Support/Firefox/Profiles"
          if [ -d "$PROFILES" ] \
            && ! grep -qs testpilot-containers "$PROFILES"/*/extensions.json; then
            notify "Work container" \
              "Install the Multi-Account Containers extension"
            exit 1
          fi

          ${firefoxLib}
          new_window_here "${workUrl}"
        '';
      };

      # HJKL, keeping the Hyprland spatial arrangement.
      directions = {
        h = "left";
        j = "down";
        k = "up";
        l = "right";
      };

      # 1..9 are workspaces of the same name; the 0 key takes workspace 10,
      # exactly as $mod+0 does in hyprland.nix.
      workspaces = (map (n: {
        key = toString n;
        name = toString n;
      }) (lib.range 1 9))
      ++ [
        {
          key = "0";
          name = "10";
        }
      ];

      binds = lib.listToAttrs (
        # --- Directional focus and move -----------------------------------
        # The pair Rectangle could not provide: it had no way to change which
        # window is focused, so the whole select tier sat empty.
        lib.mapAttrsToList (k: d: lib.nameValuePair "${mod}-${k}" "focus ${d}") directions
        ++ lib.mapAttrsToList (k: d: lib.nameValuePair "${modShift}-${k}" "move ${d}") directions

        # --- Workspaces ---------------------------------------------------
        ++ map (w: lib.nameValuePair "${mod}-${w.key}" "workspace ${w.name}") workspaces
        ++ map (
          w: lib.nameValuePair "${modShift}-${w.key}" "move-node-to-workspace ${w.name}"
        ) workspaces
      )
      // {
        # --- Monitors: the primary gesture, on U ----------------------------
        # U toggles which display is focused; U with shift throws the focused
        # window there. `next --wrap-around` IS a toggle on a two-display setup
        # — from either monitor it lands on the other — and degrades sensibly to
        # a cycle if a third display ever appears.
        #
        # U because the deleted rectangle.nix used U/I/O for this row and I is
        # already the centred-master snap. One key beats reaching for arrows on
        # the gesture used dozens of times a day.
        #
        # --focus-follows-window matches what the old skhdrc did by hand
        # (`yabai -m window --display 1; yabai -m display --focus 1`) — you
        # almost always want to go with the window you just threw.
        "${mod}-u" = "focus-monitor --wrap-around next";
        "${modShift}-u" = "move-node-to-monitor --focus-follows-window --wrap-around next";

        # --- Monitors: explicit direction, on the ARROW keys ----------------
        # Kept alongside U for when the target matters rather than just "the
        # other one". The physical arrangement here is VERTICAL — verified from
        # NSScreen: the Dell U4924DW sits at y=0 and the built-in at y=-982, and
        # NSScreen's y axis points up, so the laptop is genuinely *below* the
        # ultrawide. So down = laptop, up = ultrawide.
        #
        # Arrows rather than letters because H/J/K/L are taken on both tiers by
        # within-workspace focus and move, and because hyprland reaches for a
        # third modifier tier here ($mod CTRL SHIFT + H/J/K/L) which cannot be
        # expressed with only ⌃⌥⌘ and ⌃⌥⇧⌘ available.
        #
        # No --wrap-around on these, deliberately: a directional key should fail
        # at the edge rather than silently sending a window to the opposite end.
        # "No monitors in direction up" from the top display is correct.
        "${mod}-left" = "focus-monitor left";
        "${mod}-down" = "focus-monitor down";
        "${mod}-up" = "focus-monitor up";
        "${mod}-right" = "focus-monitor right";
        "${modShift}-left" = "move-node-to-monitor --focus-follows-window left";
        "${modShift}-down" = "move-node-to-monitor --focus-follows-window down";
        "${modShift}-up" = "move-node-to-monitor --focus-follows-window up";
        "${modShift}-right" = "move-node-to-monitor --focus-follows-window right";

        # --- Monitors: whole workspace, on comma/period ---------------------
        # The direct analogue of hyprland's movecurrentworkspacetomonitor: moves
        # every window at once, not just the focused one. Comma/period is the
        # precedent Rectangle set for display movement, and these are the only
        # binds for the workspace-level operation — U and the arrows above are
        # all single-window.
        #
        # The focus-monitor pair that used to sit on unshifted comma/period is
        # gone: U now does that job in one key, and two bindings for the same
        # command is how a keymap rots.
        "${modShift}-comma" = "move-workspace-to-monitor --wrap-around prev";
        "${modShift}-period" = "move-workspace-to-monitor --wrap-around next";

        # --- Layout --------------------------------------------------------
        # hyprland's $mod Y toggles hy3↔master; this toggles tiles↔accordion,
        # the same "switch the whole layout" gesture. Accordion is also the
        # nearest thing to an hy3 tab group ($mod W) — it stacks siblings and
        # shows a sliver of each, but there is no tab bar and no
        # hy3:focustab, so $mod O/U have no equivalent and are unbound.
        "${mod}-y" = "layout tiles accordion";
        "${mod}-w" = "layout accordion";
        "${modShift}-w" = "layout tiles";

        # The 1/4 | 1/2 | 1/4 centred-master snap, which needs three tiled
        # windows; with two it balances them and with one it declines, because
        # neither is expressible in AeroSpace's tiling model (see the WINDOW
        # COUNTS note on centerMaster). On I because the deleted
        # rectangle.nix put this very layout on U/I/O — "U I O sit directly
        # above J K L and read left / middle / right" — and I was its
        # centreHalf. Nothing sits on U/O now: with a real tiling WM the side
        # columns place themselves, so only the centre needs a key.
        "${mod}-i" = "exec-and-forget ${lib.getExe centerMaster}";
        # Flip the orientation of the current container — hy3's implicit
        # behaviour when you split against the grain.
        "${mod}-slash" = "layout horizontal vertical";

        # --- Window state --------------------------------------------------
        "${mod}-f" = "layout floating tiling"; # $mod F togglefloating
        "${modShift}-f" = "fullscreen"; # $mod SHIFT F
        "${mod}-q" = "close"; # $mod Q killactive
        "${modShift}-r" = "reload-config"; # $mod SHIFT R hyprctl reload

        # $mod SHIFT Return is hy3:makegroup v — "put this window in a new
        # vertical group". join-with is AeroSpace's version: it pulls the
        # focused window and its neighbour under a common parent.
        #
        # DO NOT use `split vertical` here, which looks like the closer match
        # and is what this binding was first written as. AeroSpace refuses to
        # load a config that pairs `split` with
        # enable-normalization-flatten-containers = true, and says so plainly:
        #
        #   These two settings don't play nicely together. 'split' command has
        #   no effect when enable-normalization-flatten-containers is disabled.
        #
        # `split` exists solely for i3 compatibility (its own man page says so)
        # and the normalizations keep flattening what it builds. Upstream's
        # advice is to keep the normalizations and use join-with, so that is
        # what this does. The full directional set is in the service mode below;
        # this is the fast path for the common case.
        "${modShift}-enter" = "join-with down";

        # --- Resize --------------------------------------------------------
        # No hyprland equivalent bound today (that config resizes by mouse via
        # bindm), but AeroSpace has no mouse-drag resize binding, so the
        # keyboard pair is the only route.
        "${mod}-minus" = "resize smart -50";
        "${mod}-equal" = "resize smart +50";

        # --- Launchers -----------------------------------------------------
        # $mod Return → ghostty, matching hyprland. -n forces a new instance
        # rather than raising the existing one; -a takes the app name because
        # ghostty-bin is aliased into /Applications/Nix Apps by the host.
        #
        # hyprland's remaining launchers ($mod R rofi, $mod T/G file managers)
        # have no mac equivalent here and stay unbound.
        "${mod}-enter" = "exec-and-forget open -na Ghostty";

        # $mod B / $mod A, mirroring hyprland (browser, and browser at
        # claude.ai).
        #
        # Addressed by BUNDLE ID, not app name. Firefox on this host is
        # installed by hand into /Applications, NOT through Nix — nothing in
        # this repo manages it — so `open -a Firefox` would depend on the app
        # keeping that exact filename. The bundle id survives a rename or a move
        # and is what LaunchServices actually keys on. Verified live:
        # org.mozilla.firefox resolves to /Applications/Firefox.app.
        #
        # $mod+B goes through newWindow above rather than `open`, so it produces
        # a WINDOW like hyprland's `exec, firefox` does — `open` merely activates
        # an already-running Firefox, and `open -n` would start a rival instance
        # that fights over the profile lock. See newWindow for the full note.
        #
        # $mod+A stays on `open` with a URL, which is correct parity: on Linux
        # `firefox <url>` against a running instance opens a TAB too.
        "${mod}-b" = "exec-and-forget ${lib.getExe newWindow}";
        "${mod}-a" = "exec-and-forget open -b org.mozilla.firefox https://claude.ai";

        # $modShift+B → a tab in the Work container, so Shift means "the work
        # variant of the browser" the same way Shift means "the move variant"
        # everywhere else in this keymap. See workContainer above for why this
        # has to drive a menu instead of opening a URL, and for the one
        # permission it needs.
        "${modShift}-b" = "exec-and-forget ${lib.getExe workContainer}";

        # --- Misc ----------------------------------------------------------
        # AeroSpace's default config puts this on alt-tab, which AltTab owns.
        "${mod}-tab" = "workspace-back-and-forth";
        "${mod}-semicolon" = "mode service";
      };

      # Upstream's service mode, kept close to the shipped default-config.toml.
      # join-with is the real hy3:makegroup — it pulls the focused window and
      # its neighbour under a common parent — and it lives here rather than on
      # a top tier because it is a reshaping tool, not a daily motion.
      serviceBinds = lib.listToAttrs (
        lib.mapAttrsToList (k: d: lib.nameValuePair k [ "join-with ${d}" "mode main" ]) directions
      )
      // {
        esc = [
          "reload-config"
          "mode main"
        ];
        # Reset the workspace tree — the closest thing to "undo my layout".
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];
      };
    in
    {
      services.aerospace = {
        enable = true;

        settings = {
          # Required for persistent-workspaces; see the header.
          config-version = 2;

          # Immutable store path — nothing to watch. See the header.
          auto-reload-config = false;

          # Keep the numbered set alive even when empty, so the ten
          # workspaces behave like hyprland's fixed 1..10 rather than
          # appearing and vanishing.
          persistent-workspaces = map (w: w.name) workspaces;

          default-root-container-layout = "tiles";
          # 'auto' picks horizontal for wide monitors and vertical for tall
          # ones, which is what the two docked setups want: the 5120px Dell
          # ultrawide splits into columns, a portrait portable into rows.
          default-root-container-orientation = "auto";

          # Matches gaps_in / gaps_out in hyprland.nix so the machines feel
          # the same. Defined as gapInner/gapOuter above because centerMaster
          # needs the same numbers to compute column widths — changing a gap
          # here must not silently skew that arithmetic.
          gaps = {
            inner.horizontal = gapInner;
            inner.vertical = gapInner;
            outer.left = gapOuter;
            outer.right = gapOuter;
            outer.top = gapOuter;
            outer.bottom = gapOuter;
          };

          # hyprland.nix sets input.follow_mouse = 1, but the mac history is
          # contradictory about wanting it — the yabai config carried both
          # `focus_follows_mouse off` and, in a later revision,
          # `focus_follows_mouse autoraise`. Left off (AeroSpace's own
          # default); flip to true for Hyprland parity.
          focus-follows-mouse.enabled = false;

          # Warp the pointer when the focused monitor changes. This is the
          # AeroSpace default and also the nix-darwin module default, stated
          # here because it is the surviving half of the yabai config's
          # `mouse_follows_focus on`.
          on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

          # NO on-window-detected CALLBACK. There used to be one, matching every
          # app, whose whole job was undoing the float-based snap when a new
          # window landed on top of it. Both halves are gone — see the header.
          # If one is ever added back, note that nix-darwin types `if` as a
          # submodule with default {}, so an omitted matcher still emits an empty
          # `[on-window-detected.if]` table and AeroSpace complains ("Omitting
          # 'if' is error prone. You can use `if = 'true'` ..."); the new-style
          # `if = 'true'` is not expressible through that submodule type, so the
          # legacy equivalent is app-name-regex-substring = ".*".
          # check-further-callbacks matters as soon as there is more than one.

          # Pin workspaces to monitors — the declarative version of what
          # hyprland.nix's monitorAttached script does imperatively (move
          # workspaces 1-6 to the external) and what its commented-out
          # `workspace = [...monitor:...]` block tried. Left empty because the
          # patterns are monitor names, which differ per dock; fill from
          # `aerospace list-monitors`, e.g.
          #   workspace-to-monitor-force-assignment = {
          #     "1" = "dell";        # matches the U4924DW ultrawide
          #     "7" = "built-in";
          #   };
          workspace-to-monitor-force-assignment = { };

          mode.main.binding = binds;
          mode.service.binding = serviceBinds;
        };
      };

      # THE DEAD-SERVER HEAL, and why activation needs one.
      #
      # WHAT BROKE. The plist pins the store path of the binary, so it changes
      # on EVERY version bump, and activation then replaces the agent with
      # `launchctl unload` + `load -w`. On the 0.21.2 → 0.21.3 bump the instance
      # that came up was alive but had never opened its socket
      # (/tmp/bobko.aerospace-$USER.sock): the server was dead, so `aerospace`
      # exited "Connection refused" and — since AeroSpace owns its own
      # keybindings — not one hotkey worked. Nothing was logged anywhere, and it
      # presents exactly like a revoked Accessibility grant, which is the wrong
      # tree to bark up (see below).
      #
      # WHAT IS VERIFIED. A clean bootout-then-bootstrap recovers it. Two
      # tempting explanations are ruled out: a leftover socket file is NOT the
      # blocker (AeroSpace does leave one behind on SIGTERM, but a fresh
      # instance rebinds straight over it — tested), and Accessibility is NOT
      # revoked by the path change (the same binary enumerates windows through
      # the AX API once its server is up, adhoc signature notwithstanding).
      #
      # WHAT IS NOT KNOWN: why that particular start came up server-less. The
      # likeliest story is a race between the outgoing and incoming instances
      # during unload/load, but it did not reproduce on demand, so this heals
      # the observed end state rather than a mechanism it cannot prove.
      #
      # HENCE PROBE-THEN-RESTART. Ask the server whether it answers and act only
      # if it does not: an unconditional restart on every rebuild would tear
      # down a healthy WM for nothing. bootout-then-bootstrap rather than
      # `kickstart -k` because bootout waits for the old process to be gone
      # before the new one starts, and that is the sequence actually observed to
      # recover. Runs in postActivation because that is after the block that
      # reloads user agents — probing earlier would read the state of the
      # instance about to be killed. `asuser` + `sudo` is how nix-darwin itself
      # reaches the user's GUI launchd domain from a root activation script.
      system.activationScripts.postActivation.text =
        let
          user = config.system.primaryUser;
          cli = "${config.services.aerospace.package}/bin/aerospace";
          agent = "org.nixos.aerospace";
        in
        ''
          echo "checking AeroSpace server..." >&2
          aeroUid=$(id -u ${user} 2>/dev/null || true)
          if [ -n "$aeroUid" ]; then
            # ~5s of grace: a just-loaded agent takes a moment to bind, and
            # treating "still starting" as "dead" would restart it for nothing.
            aeroProbe() {
              for _ in 1 2 3 4 5 6 7 8 9 10; do
                launchctl asuser "$aeroUid" sudo --user=${user} -- \
                  ${cli} list-workspaces --focused >/dev/null 2>&1 && return 0
                sleep 0.5
              done
              return 1
            }
            if ! aeroProbe; then
              echo "  server not answering; restarting the agent" >&2
              launchctl asuser "$aeroUid" sudo --user=${user} -- \
                launchctl bootout "gui/$aeroUid/${agent}" || true
              launchctl asuser "$aeroUid" sudo --user=${user} -- \
                launchctl bootstrap "gui/$aeroUid" \
                ~${user}/Library/LaunchAgents/${agent}.plist || true
              if aeroProbe; then
                echo "  recovered" >&2
              else
                echo "  STILL not answering — launchctl print gui/$aeroUid/${agent}" >&2
              fi
            fi
          fi
        '';
    };
}
