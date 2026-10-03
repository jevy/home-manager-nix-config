# Noctalia shell: replace ashell, mako, rofi, hyprlock

Date: 2026-10-03
Host: lenovo-p14s (via `linuxDesktopBase`)
Status: design approved in chat, spec awaiting review

## Acceptance checklist

Run after switching `desktopShell` to `"noctalia"` and `rebuildhm`. Every box must
tick before the old stack is deleted.

```
[ ] Bar shows on every monitor; workspaces switch
[ ] Calendar widget shows meetings; turns red within 15 min; click opens gcal
[ ] Weather widget shows text; click opens wttr popup
[ ] Volume keys change volume + show OSD
[ ] Brightness keys still drive DDC + now show OSD
[ ] notify-send appears; `notify-send -u critical` stays until dismissed
[ ] Super+N clears notifications
[ ] `notify-send -a Spotify test` shows no toast (mako's hidden-app rules carried over)
[ ] Super+P / idle lock shows exactly ONE lock screen
[ ] Super+R launcher, Super+C calc, Super+. emoji, Super+V clipboard
[ ] Tray: icons appear; open VLC from yazi -> window in <2s (not 25s)
[ ] Super+P locks; password unlocks with NO 30s wait (#3277 fix)
[ ] Fingerprint unlocks the lock screen
[ ] Lid close -> suspend -> resume: locked, fingerprint still works
[ ] sudo fingerprint still works after an unlock (#4591 check)
[ ] Colors match gruvbox-material (stylix target)
[ ] Art tool wallpaper still shows; Noctalia draws no background over it
[ ] Lock screen background is acceptable without a Noctalia wallpaper
```

## Goal

Overhaul the Hyprland desktop shell. Replace five separate tools with Noctalia v5,
keep stylix as the single source of colors, keep the two custom bar widgets that
matter day to day, and keep a one-line path back to the current stack.

What the user said:
- Wants an overhaul and upgrade, not a like-for-like bar swap.
- Chose Noctalia v5 over Caelestia because custom widgets are possible as Lua
  plugins without forking.
- Replace everything (bar, notifications, launcher, lock) "unless we find it
  breaks something".
- Stylix stays the color source.
- Day-one widgets: calendar meetings and the existing weather script. TimeTagger
  can follow later.
- Approach A: nixpkgs package + home-manager module + a rollback switch.
- Wallpaper stays with the user: hyprpaper plus their own art download and
  display tool. Noctalia must not draw a wallpaper.

Confirmed in review:
- hypridle stays as the idle/sleep manager; only its lock command changes.
- hyprpolkitagent and the polkit grosshack PAM stay.

## Background facts (verified 2026-10-03)

- Noctalia v5 is a native C++/OpenGL ES rewrite. The Quickshell-based v4
  (`pkgs.noctalia-shell`, 4.7.7) is end of life.
- nixpkgs (our pin) ships `pkgs.noctalia` 5.1.0. Upstream is at 5.2.1.
- home-manager (our pin) ships `programs.noctalia`: `enable`, `package`,
  `systemd.enable`, `settings` (Nix attrs -> TOML), `customPalettes`,
  `checkConfig` (runs `noctalia config validate` at build time).
- stylix (our pin, 2026-08-26) has a `noctalia` target that writes a custom
  palette from base16, sets `theme.mode`, font family and popup opacities.
- `noctalia msg --help` on 5.1.0 lists, among others: `volume-up [step]`,
  `volume-down [step]`, `volume-mute`, `brightness-osd <value>`,
  `notification-clear-active`, `panel-toggle <id> [context]`, `session <action>`,
  `wallpaper-set [connector] <path>`, `config-reload`. `noctalia dmenu` reads
  choices from stdin.
- Plugins: `plugin.toml` manifest (`id = "author/name"`, `plugin_api`,
  `[[widget]] id/entry`), Luau entry scripts. Bar widget API includes
  `setText`, `setGlyph`, `setTooltip`, `setColor`, `onClick`, `update`,
  `onExit`. Runtime API includes `noctalia.runStream(cmd, onLine)` and
  `noctalia.runAsync(cmd, cb)`.
- Open lock bugs:
  - #3277 (open): lock uses hard-coded `login` PAM service; with
    `pam_fprintd` in that stack, password unlock waits ~30s.
    `security.pam.services.login.fprintAuth` is currently `true`.
  - #4591 (closed 2026-10-02): fprintd left claimed after verify-disconnected.
    Fix is not in 5.1.0.

## Architecture

```
modules/hosts/linux-desktop-base.nix
      |  desktopShell = "noctalia"   ("noctalia" | "legacy")
      v
+------------- "noctalia" -------------+   +------------ "legacy" ------------+
| homeManager.noctalia     (new)       |   | homeManager.ashell               |
|   programs.noctalia + systemd        |   | homeManager.mako                 |
|   stylix.targets.noctalia (colors)   |   | rofi bindings                    |
|   plugins: calendar, weather (Luau)  |   | hyprlock + hypridle lock_cmd     |
| nixos.noctaliaLock       (new)       |   |                                  |
|   login PAM fprintAuth = false       |   |                                  |
+--------------------------------------+   +----------------------------------+
      Hyprland and clipboard binds choose their commands from the same option
```

### Units

| Unit | File | Responsibility |
|---|---|---|
| Switch | `modules/desktop/desktop-shell.nix` (`flake.modules.nixos.desktopShell` + `flake.modules.homeManager.desktopShell`) | Declares `options.desktopShell = enum [ "legacy" "noctalia" ]`, default `"legacy"`, in both module systems. `linux-desktop-base.nix` sets it once from a single `let` binding, for NixOS and for `home-manager.users.jevin`, so the two sides cannot disagree. No `osConfig`, no specialArgs. |
| Noctalia HM module | `modules/desktop/noctalia.nix` (`flake.modules.homeManager.noctalia`) | `programs.noctalia` settings, systemd service bound to `hyprland-session.target`, weather wrapper (reads sops key), plugin installation. |
| Noctalia NixOS module | same file (`flake.modules.nixos.noctaliaLock`) | `security.pam.services.login.fprintAuth = false`. |
| Calendar plugin | `modules/desktop/noctalia-plugins/calendar/{plugin.toml,widget.luau}` | Stream `waybar/polybar/ashell-calendar.sh`, render text/tooltip, `setColor("error")` when urgent, click opens Google Calendar. |
| Weather plugin | `modules/desktop/noctalia-plugins/weather/{plugin.toml,widget.luau}` | Stream the weather wrapper, render text, click opens the wttr.in popup. |
| Hyprland binds | `modules/desktop/hyprland.nix` | Pick commands per `desktopShell`. Wallpaper start-up and hotplug scripts are untouched. |
| Clipboard binds | `modules/desktop/clipboard.nix` | `Super+V` and `Super+.` per `desktopShell`. |

Legacy modules (`ashell.nix`, `mako.nix`, hyprlock config) are not edited beyond
what the switch needs to include or exclude them. Both stacks' modules stay
imported; each guards its config with `lib.mkIf (config.desktopShell == ...)`.

## Mapping

| Today | Noctalia | Bind / caller |
|---|---|---|
| ashell bar | Bar: workspaces / calendar plugin (center) / weather plugin, media, tray, volume, clock (right) | n/a |
| ashell volume OSD | `noctalia msg volume-up 10`, `volume-down 10`, `volume-mute` | XF86 volume keys |
| brightness (no OSD) | `brightnessAdjust` unchanged, then `noctalia msg brightness-osd <value>` | keys 232/233 |
| mako | Noctalia notifications | `Super+N` = `notification-clear-active` (clears all active) |
| mako app rules: hide Spotify, Slack, Obsidian, cloud-drive-ui | `[notification.filter.*]` with `show_toast = false` | n/a |
| mako app rule: Frigate 256px icons, 400px width | **Dropped.** Noctalia has no per-app icon size or width. Known loss. | n/a |
| rofi run | `noctalia msg panel-toggle launcher` (searches .desktop apps, not $PATH binaries as `rofi -show run` did) | `Super+R` |
| rofi calc | `noctalia msg panel-toggle launcher "/calc "` | `Super+C` |
| rofi emoji | `noctalia msg panel-toggle launcher "/emo "` | `Super+.` |
| rofi + cliphist | `cliphist list \| noctalia dmenu \| cliphist decode \| wl-copy` | `Super+V` |
| hyprlock | `noctalia msg session lock`. hypridle keeps calling `loginctl lock-session`; Noctalia answers that logind signal itself ("`loginctl lock-session` uses the same path when Noctalia is running", v5.1.0 IPC docs), so hypridle `lock_cmd` is **empty** on noctalia to avoid a double lock | `Super+P` |
| hyprpaper + user's art tool | Unchanged. Noctalia `wallpaper.enabled = false` (verified as a known key on 5.1.0) so it never draws a background layer | n/a |
| ashell tray watchdog | not imported on noctalia | n/a |
| TimeTagger widget | not ported (follow-up); `XF86Launch6/7` unchanged | n/a |

Not enabled: dock, desktop widgets, night light, Noctalia screenshot/annotate.

## Plugins

Data flow for both widgets:

```
existing listen script --stdout JSON lines--> runStream onLine
    --> parse {"text", "alt"} --> setText / setTooltip / setColor
```

- Scripts are reused unchanged. The ashell custom-module JSON
  (`{"text": ..., "alt": ...}`) is the contract. Calendar urgent state is
  `"alt": "urgent"` (verified in `ashell-calendar.sh`, meeting within 10 min).
- Failure handling: each stream command is a Nix-built shell loop that reruns
  the script and, whenever it exits, prints
  `{"text": "<name> unavailable", "alt": "error"}` and sleeps 15s. The widget
  renders `alt == "error"` in the error color. `runStream` gives Luau no exit
  callback (verified in v5.1.0 `luau_host.cpp`), so restart lives in the shell.
- Store paths (stream command, click command) are substituted into the `.luau`
  files at build time. No per-widget settings keys, so the strict config check
  below never sees plugin-specific keys.
- Install: one Nix derivation holding `calendar/` and `weather/`, registered as a
  `[[plugins.source]]` with `kind = "path"` (v5.1.0 docs: "an immutable local
  directory ... ideal for Nix-managed plugins") and listed in
  `[plugins] enabled`. Bar entries: `jevin/calendar:meetings`,
  `jevin/weather:forecast`.
- Build checks: `luau-compile --null` on every `.luau` (fails on syntax errors).

## Config drift

```
Nix settings --> ~/.config/noctalia/config.toml        (read-only, from Nix)
GUI tweaks  --> ~/.local/state/noctalia/settings.toml  (WINS over config.toml)
```

- Nix is the source of truth. GUI is for experimenting; keepers get copied into
  `noctalia.nix`.
- Rebuilds do not delete the state file.
- `noctalia.nix` header documents this and the check command:
  `cat ~/.local/state/noctalia/settings.toml`.

## Error handling and risks

| Risk | Mitigation |
|---|---|
| #3277 30s password wait | `login.fprintAuth = false`. Cost: no fingerprint at a TTY login only. |
| #4591 fprintd stays claimed (fix not in 5.1.0) | Checklist item. If hit: overlay the upstream patch onto `pkgs.noctalia`, or move to the upstream flake (approach B). |
| Suspend before lock is up | Keep hypridle's existing before-sleep ordering; re-verify it waits for Noctalia's ext-session-lock. |
| Critical notifications auto-dismiss | Checklist item; set Noctalia's critical timeout to never if needed (`backup-notify.nix` depends on it). |
| GUI state overrides Nix | Documented rule above. |
| Anything else breaks | Set `desktopShell = "legacy"`, `rebuildhm`. |

## Testing

- Build time: `nix flake check`. `noctalia config validate` only WARNS on an
  unknown key and still exits 0 (verified on 5.1.0), so the module replaces the
  HM `checkConfig` with a strict check that fails the build when validate
  prints `unknown setting`.
- With `desktopShell = "legacy"`, the lenovo-p14s system derivation must be
  byte-identical to the pre-change one.
- Build both `desktopShell` values so the rollback path always evaluates.
- Live: the acceptance checklist at the top.

## Rollout

1. Commit: switch option (default `"legacy"`), Noctalia module, plugins, PAM
   change wired to the switch. Rebuild: no visible change.
2. Commit: set `desktopShell = "noctalia"`. Rebuild, run the checklist.
3. On failure: set back to `"legacy"`, rebuild. A lock-only fallback is not
   built up front; add one if the lock turns out to be the only problem.
4. After about two weeks clean: delete ashell, mako, rofi config, hyprlock
   config, tray watchdog, the yazi tray note, and the switch.

## Out of scope

- TimeTagger widget port.
- Noctalia greeter, dock, desktop widgets, night light, screenshot tools.
- mac-work (aerospace/yabai) is unaffected.
