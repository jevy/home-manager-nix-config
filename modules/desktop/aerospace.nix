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
# WHY NOT YABAI. The retired yabai/skhd config is still in
# modules/apps/desktop-mac.nix (dormant, packages commented out). Its skhdrc
# carries the note that killed it:
#
#   # Turned off in favor for Hammerspoon as it doesn't need disabling of
#   # MacOS security
#
# yabai's tiling needs its scripting addition, which needs SIP partially
# disabled; the fallback was Hammerspoon's hs.spaces, which switches Spaces but
# cannot tile. AeroSpace resolves that trade-off rather than picking a side: it
# needs no SIP changes at all, because it does not drive Mission Control. It
# emulates workspaces by moving windows off-screen instead.
#
# FUTURE WORK, if centerMaster's hackiness ever stops being worth it. Two
# separate complaints hide inside "this feels hacky", and only one of them is
# essential:
#
#   * THE SCRIPT EXISTING AT ALL is AeroSpace's doing. No master layout, no
#     declarative split ratio, and node weights reachable only through the
#     `resize` command — so a 25/50/25 has to be applied imperatively to the
#     windows that happen to be open. That is also why nothing self-maintains
#     and mod+I has to be pressed again after every open or close.
#   * THE FLOAT + ACCESSIBILITY DETOUR for a lone window is NOT AeroSpace being
#     deficient; a lone window fills its container in essentially every tiler.
#     "One window should be half width" is smart-gaps territory, not tiling.
#     Note it is not even Hyprland parity: master with orientation = center and
#     mfact = 0.45 also gives a single window the whole screen unless
#     always_center_master is added.
#
# The candidates, ranked by what they would actually buy:
#
#   1. YABAI has the one clean primitive for the single-window case: per-space
#      padding, settable at runtime (`yabai -m space --padding abs:...`), so a
#      lone window narrows with no floating and no Accessibility API at all.
#      Its signals (window_created / window_destroyed) would also make the
#      ratio self-maintaining rather than a keypress.
#
#      BEFORE ACTING ON THIS, VERIFY THE PREMISE ABOVE — it is probably stale.
#      The claim that yabai's *tiling* needs the scripting addition looks wrong
#      for modern yabai, where the addition is believed to be required mainly
#      for space create/destroy, cross-display moves, opacity/borders and
#      similar extras, with plain tiling and padding working without it. That is
#      UNVERIFIED as of this writing and is the single highest-value thing to
#      check, since the whole choice of WM rests on it.
#   2. AMETHYST fixes the self-maintenance properly: a real three-column layout
#      with a main-pane ratio, kept as windows come and go, needing only
#      Accessibility and no SIP changes. But it has the same lone-window
#      behaviour, no workspace model to replace AeroSpace's, and a plist rather
#      than anything Nix-shaped. Trading workspaces for a ratio is a bad deal.
#   3. PER-MONITOR OUTER GAPS, which AeroSpace supports declaratively, e.g.
#      gaps.outer.left = [{ monitor.dell = 1274 }, 8]. Zero script and zero
#      Accessibility, and a lone window is natively centred at the master
#      width — but it caps the ENTIRE tiling area at that width, so the
#      three-column case dies. Only sensible if the ultrawide's outer thirds
#      turn out to be wasted space anyway.
#
# RECOMMENDATION: stay on AeroSpace. It does the four things that matter daily
# — workspaces, directional focus, moves, monitors — and each replacement costs
# one of them. The single-window branch is contained: ~25 lines, idempotent, and
# it fails loudly rather than silently.
#
# A HAMMERSPOON EXECUTOR was the fallback here, for the case where AeroSpace's
# Accessibility grant did not reach the scripts it spawns — it is a stable app
# path, so its grant would survive rebuilds where a Nix-built helper's would
# not, and it would narrow the blast radius from "any script can drive any app"
# to one app this config controls. It proved unnecessary: the grant does carry,
# and nothing had to be granted by hand (see the ACCESSIBILITY note on
# centerMaster). Revisit only if that stops being true.
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
    { lib, pkgs, ... }:
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
      # WINDOW COUNTS. The centre column is AVAIL/2, so what this key has to do
      # depends on how many windows are tiled:
      #
      #   3  the original case: shrink the centre to AVAIL/2, sides fall out
      #      equal at AVAIL/4 each (see the resize note below)
      #   2  nothing to do. Two equal columns are AVAIL/2 each, which already IS
      #      the centre width, so balance-sizes alone is the whole job
      #   1  a lone window fills the monitor, and no AeroSpace command can
      #      narrow it — see below
      #
      # THE ONE-WINDOW CASE needs a different mechanism, and this is the part
      # worth reading before changing anything here. Three things were measured
      # on 0.21.2-Beta against a live lone window on the 5120 ultrawide:
      #
      #   1. `resize width N` EXITS 2 AND DOES NOTHING, silently, with no error
      #      message at all. resize spreads its delta across siblings, and a
      #      lone window has none, so there is nothing to take the space. This
      #      is not a bug to work around; there is no tiling route to a narrow
      #      single window.
      #   2. Setting the frame through the Accessibility API while the window is
      #      still TILED is reverted synchronously — a read taken immediately
      #      after the write, with no sleep, already shows the full 5104 back.
      #      AeroSpace reconciles tiled frames, so this is not a race that a
      #      delay or a retry could win.
      #   3. Setting the frame on a FLOATING window sticks, exactly, and
      #      survives focus and monitor changes. AeroSpace does not manage
      #      floating geometry (`resize` says so outright: "resize command
      #      doesn't support floating windows yet", upstream issue #9), and that
      #      hands-off behaviour is what makes this work.
      #
      # So the single-window path floats the window and sets its frame itself.
      # The order matters: it tiles the window FIRST and reads the rect while it
      # is still full-width, because that rect is the measurement. A press with
      # the window already floating would otherwise read the narrowed frame and
      # halve it again on every press.
      #
      # That read also removes the NSScreen lookup from this path entirely. The
      # tiled rect already has the outer gaps applied by AeroSpace, so its width
      # is AVAIL + 2*INNER and the target is (W - 2*INNER)/2 — the same number
      # the three-window branch computes from the monitor, but derived from the
      # window, so it is correct on any monitor with no index arithmetic.
      # Verified live: 5104 wide at x=8 gives 2548 at x=1286, matching the 2548
      # the three-window snap produces, and repeated presses are idempotent.
      #
      # THE COST is that the window is now floating: it no longer tiles, so a
      # second window opens at full width underneath it. mod+F (layout floating
      # tiling) puts it back, and two tiled windows are AVAIL/2 each anyway, so
      # the recovery is one key. The notify below says so when it sees floating
      # windows rather than reporting a misleading tiled count.
      #
      # ACCESSIBILITY, and it needs NO grant of its own — verified live, by
      # pressing the key and finding the window at exactly 2548 wide and x=1286.
      # Only the AX write produces that geometry, so the write succeeded from a
      # script AeroSpace spawned with exec-and-forget.
      #
      # THE MECHANISM IS THE RESPONSIBLE PROCESS, not the executable, and the
      # difference matters if this ever appears to break. osascript has no grant
      # of its own: the identical AX read run from launchd fails with "osascript
      # is not allowed assistive access. (-1719)", while from a terminal it
      # succeeds, because TCC attributes a child's request to the responsible
      # ancestor rather than to the binary making it. AeroSpace holds
      # Accessibility already — it cannot manage windows without it — so
      # everything it spawns inherits the grant.
      #
      # This narrows the per-executable claim made elsewhere in this file (see
      # the workContainer notes, where a broad grant for /usr/bin/osascript is
      # described as necessary). For GEOMETRY the grant carries and nothing had
      # to be granted by hand. If a UI-driving script genuinely still fails
      # under AeroSpace, the difference is not "TCC is per-executable"; look for
      # another cause.
      #
      # It is still osascript rather than a compiled helper, and deliberately:
      # TCC keys a grant to a path, and every rebuild gives a Nix-built binary a
      # NEW store path, which would silently drop the grant on each rebuild.
      # /usr/bin/osascript is Apple-signed at a stable path, so a grant given
      # once survives. Read-only geometry is all this needs; it drives no menus.
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

          # One step left or right, non-zero at the workspace edge so the walks
          # below terminate. --ignore-floating keeps floating windows out.
          step() {
            aerospace focus --ignore-floating \
              --boundaries workspace --boundaries-action fail "$1" >/dev/null 2>&1
          }

          # Frame of the focused window, for the one-window case only. window 1
          # of the frontmost process IS the focused window: AX orders an app's
          # windows front to back. Both halves are one osascript call so the
          # size/position/size ordering cannot be split up — setting size first
          # keeps a shrink from being clipped at the screen edge, and setting it
          # again after the move is the belt-and-braces AX convention.
          ax_rect() {
            /usr/bin/osascript -e 'tell application "System Events" to tell (first process whose frontmost is true) to get {position, size} of window 1'
          }
          ax_set() {
            /usr/bin/osascript -e "tell application \"System Events\" to tell (first process whose frontmost is true)
                set size of window 1 to {$3, $4}
                set position of window 1 to {$1, $2}
                set size of window 1 to {$3, $4}
              end tell"
          }

          # Window count INCLUDING floating ones. The walk below counts only
          # tiled windows, which is the wrong basis for the one-window test:
          # with one tiled and one floating window the walk also says 1, and
          # floating the tiled one on top of it is not what this key means.
          WS=$(aerospace list-workspaces --focused)
          TOTAL=$(aerospace list-windows --workspace "$WS" \
                    --format '%{window-id}' | grep -c . || true)

          # --- ONE WINDOW: float it and centre it at the master width -------
          # See the header for why this cannot be done with resize, and why the
          # rect has to be read while the window is still tiled.
          if [ "$TOTAL" -eq 1 ]; then
            aerospace layout tiling >/dev/null 2>&1 || true

            RECT=$(ax_rect 2>/dev/null | tr -d ',' || true)
            X=$(printf '%s\n' "$RECT" | awk '{print $1}')
            Y=$(printf '%s\n' "$RECT" | awk '{print $2}')
            W=$(printf '%s\n' "$RECT" | awk '{print $3}')
            H=$(printf '%s\n' "$RECT" | awk '{print $4}')

            if [ -z "$W" ] || [ "$W" -le 0 ]; then
              notify "Centred master" \
                "No window frame — grant Accessibility to /usr/bin/osascript"
              exit 1
            fi

            # W is the full tiled width, so it already has the outer gaps
            # applied: W = AVAIL + 2*INNER, and the target is the centre column
            # AVAIL/2. No monitor lookup, so this is right on any display.
            TARGET=$(( (W - 2 * INNER) / 2 ))
            NEWX=$(( X + (W - TARGET) / 2 ))

            aerospace layout floating
            if ! ax_set "$NEWX" "$Y" "$TARGET" "$H" >/dev/null 2>&1; then
              notify "Centred master" \
                "Could not set the window frame (Accessibility?)"
              exit 1
            fi
            exit 0
          fi

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

          # --- TWO WINDOWS: balance-sizes above already did the whole job ----
          # Two equal columns are AVAIL/2 each, which IS the centre width.
          if [ "$count" -eq 2 ]; then
            exit 0
          fi

          if [ "$count" -ne 3 ]; then
            # Name the actual obstacle. The usual way to land here is the sequel
            # to the one-window case above: its window is still floating, so a
            # second window tiled alone underneath it and the tiled count reads
            # 1 while the workspace plainly holds two.
            stray=$((TOTAL - count))
            if [ "$stray" -gt 0 ]; then
              notify "Centred master" \
                "$stray floating window(s) in the way — mod+F un-floats"
            else
              notify "Centred master" "Needs 1, 2 or 3 tiled windows (found $count)"
            fi
            exit 0
          fi

          center=$(printf '%s\n' "$ordered" | sed -n 2p | tr -d '[:space:]')

          # Width of the focused monitor, via its NSScreen index (1-based).
          # Only the three-window branch needs this — the one-window branch
          # derives its width from the window itself — so it is read here rather
          # than up front, where an unreadable NSScreen would fail both.
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
      # Shared by newWindow and workContainer; sets $FIREFOX. $APP carries a
      # trailing slash, so the path doubles a separator — harmless on POSIX, and
      # stripping it would need a shell parameter expansion whose brace form has
      # to be escaped inside a Nix indented string. Not worth it.
      firefoxBin = ''
        APP=$(/usr/bin/osascript -e \
          'POSIX path of (path to application id "org.mozilla.firefox")')
        FIREFOX="$APP/Contents/MacOS/firefox"
      '';

      newWindow = pkgs.writeShellApplication {
        name = "firefox-new-window";
        text = ''
          ${firefoxBin}
          exec "$FIREFOX" --new-window about:newtab
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

          ${firefoxBin}
          exec "$FIREFOX" --new-window "${workUrl}"
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

        # The 1/4 | 1/2 | 1/4 centred-master snap — and with a single window on
        # the workspace, that same centre width, floated and centred (see the
        # WINDOW COUNTS note on centerMaster). On I because the deleted
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
    };
}
