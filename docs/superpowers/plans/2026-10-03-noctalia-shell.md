# Noctalia Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace ashell, mako, rofi and hyprlock on lenovo-p14s with Noctalia v5, behind a one-line `desktopShell` switch, keeping stylix colors and the calendar and weather widgets.

**Architecture:** A `desktopShell` enum option (`"legacy"` | `"noctalia"`) is declared in both NixOS and home-manager and set once in `linux-desktop-base.nix`. Legacy modules are wrapped in `mkIf legacy`; a new `modules/desktop/noctalia.nix` is wrapped in `mkIf noctalia`. Hyprland binds pick their command per entry, so with `"legacy"` the system derivation stays byte-identical.

**Tech Stack:** Nix flake-parts (dendritic, import-tree), home-manager `programs.noctalia`, nixpkgs `noctalia` 5.1.0, stylix `noctalia` target, Luau plugins.

**Spec:** `docs/superpowers/specs/2026-10-03-noctalia-shell-design.md`

## Global Constraints

- NO `nixos-rebuild switch`, NO `rebuildhm`, NO `home-manager switch` in Tasks 1-3. Another agent works in a different worktree; only `nix build`, `nix eval`, `nix path-info` are allowed. Task 4 hands the switch to the user.
- Work only inside `/home/jevin/.config/nixpkgs/.claude/worktrees/noctalia-shell`. Never `cd` to or `git -C` the main checkout.
- Flakes only see git-tracked files: `git add` every new file before any `nix` command.
- No specialArgs, no `osConfig`. Inner modules get `inputs` by closure (CLAUDE.md).
- Package: `pkgs.noctalia` from nixpkgs (5.1.0). No new flake inputs.
- Stylix stays the color source (`stylix.targets.noctalia`, auto-enabled).
- Noctalia must never draw a wallpaper: `wallpaper.enabled = false`. hyprpaper and its exec-once/hotplug lines are untouched.
- Config validation must be strict: any `unknown setting` from `noctalia config validate` fails the build.
- With `desktopShell = "legacy"`, `nix path-info --derivation .#nixosConfigurations.lenovo-p14s.config.system.build.toplevel` must equal the baseline recorded in Task 1 Step 1.
- Comments match the repo style: explain why, record measured facts and history. No emdashes.

## Review Focus

1. Legacy drift: any whitespace or ordering change in a shared string (bind list, brightness script, hypridle settings) changes the legacy derivation. Pinned by the derivation-equality test in every task.
2. Double lock: Noctalia answers `loginctl lock-session` itself, so a non-empty hypridle `lock_cmd` on noctalia opens two lockers. Pinned by Task 3 Step 6 (`lock_cmd` absent on noctalia).
3. Typo in Noctalia settings silently ignored. Pinned by Task 2 Step 2 (bogus key must fail the build).
4. Plugin stream dies and the bar shows stale text forever. Pinned by Task 2 Step 8 (wrapper prints `alt: error` after the script exits).
5. Plugin script syntax error only discovered after login. Pinned by Task 2 Step 5 (`luau-compile --null` in the derivation).

## Shared test helpers

These two commands are used by several tasks. Run them from the worktree root.

**Legacy derivation (must match baseline):**

```bash
nix path-info --derivation .#nixosConfigurations.lenovo-p14s.config.system.build.toplevel
```

**Noctalia variant without touching the base layer.** `extendModules` sets the switch only for this evaluation:

```bash
nix build --no-link --print-out-paths --impure --expr '
  let
    flake = builtins.getFlake "git+file:///home/jevin/.config/nixpkgs/.claude/worktrees/noctalia-shell";
    sys = flake.nixosConfigurations.lenovo-p14s.extendModules {
      modules = [ { desktopShell = "noctalia"; } ];
    };
  in ATTR'
```

Replace `ATTR` with the attribute path named in the step, rooted at `sys` (for example `sys.config.system.build.toplevel`). For `nix eval` use the same expression with `nix eval --impure --raw --expr` (or `--json`).

---

### Task 1: `desktopShell` switch and legacy guards

**Files:**
- Create: `modules/desktop/desktop-shell.nix`
- Modify: `modules/hosts/linux-desktop-base.nix` (inner NixOS module args, `imports`, `home-manager.users.jevin`)
- Modify: `modules/desktop/ashell.nix` (wrap module body in `mkIf`)
- Modify: `modules/desktop/mako.nix` (wrap module body in `mkIf`)

**Interfaces:**
- Produces: NixOS option `desktopShell` and home-manager option `desktopShell`, both `types.enum [ "legacy" "noctalia" ]`, default `"legacy"`. The HM value always mirrors the NixOS value. Flake attrs `flake.modules.nixos.desktopShell`, `flake.modules.homeManager.desktopShell`.

- [ ] **Step 1: Record the baseline derivation**

Run: `nix path-info --derivation .#nixosConfigurations.lenovo-p14s.config.system.build.toplevel | tee /tmp/claude-1000/noctalia-baseline-drv`
Expected: one `/nix/store/...-nixos-system-lenovo-p14s-....drv` line. (At planning time it was `/nix/store/fyyr0mjw6hvpy3mm8r5sljxy9p41sdc6-nixos-system-lenovo-p14s-26.11.20260926.e158d9e.drv`. Record the fresh value anyway.)

- [ ] **Step 2: Write the failing test**

Run: `nix eval .#nixosConfigurations.lenovo-p14s.config.home-manager.users.jevin.desktopShell`
Expected: FAIL with `attribute 'desktopShell' missing` (or "does not exist").

- [ ] **Step 3: Create `modules/desktop/desktop-shell.nix`**

```nix
# Which desktop shell the Linux desktop runs on Hyprland:
#   "legacy"   ashell bar, mako, rofi, hyprlock (ashell.nix, mako.nix, ...)
#   "noctalia" Noctalia v5 (modules/desktop/noctalia.nix)
#
# Declared in both module systems so NixOS config (PAM) and home-manager config
# (bar, binds) can each read it. Set it ONCE, on the NixOS side, in
# modules/hosts/linux-desktop-base.nix. That file mirrors the NixOS value into
# home-manager, so the two sides can never disagree.
#
# Temporary. Once Noctalia has run clean for about two weeks, the legacy stack
# and this switch get deleted. Design:
# docs/superpowers/specs/2026-10-03-noctalia-shell-design.md
{ ... }:
let
  option =
    lib:
    lib.mkOption {
      type = lib.types.enum [
        "legacy"
        "noctalia"
      ];
      default = "legacy";
      description = "Desktop shell stack for Hyprland.";
    };
in
{
  flake.modules.nixos.desktopShell =
    { lib, ... }:
    {
      options.desktopShell = option lib;
    };

  flake.modules.homeManager.desktopShell =
    { lib, ... }:
    {
      options.desktopShell = option lib;
    };
}
```

- [ ] **Step 4: Wire it into `modules/hosts/linux-desktop-base.nix`**

Change the inner NixOS module args from `{ pkgs, lib, ... }:` to `{ pkgs, lib, config, ... }:` (the inner body never uses the outer flake-parts `config`; the outer one is only read in the top-level `let`).

Add `nixos.desktopShell` to the NixOS `imports` list, after `nixos.hyprland`:

```nix
        nixos.hyprland
        nixos.desktopShell
```

Inside `home-manager.users.jevin = { ... }`, add `homeManager.desktopShell` to `imports` right before `homeManager.ashell`, and add the mirror line next to `home.stateVersion`:

```nix
            homeManager.desktopShell
            homeManager.ashell
```

```nix
          # Mirror of the NixOS-side switch (modules/desktop/desktop-shell.nix).
          desktopShell = config.desktopShell;

          home.stateVersion = "24.11";
```

- [ ] **Step 5: Guard `modules/desktop/ashell.nix`**

Change the module args from `{ config, pkgs, ... }:` to `{ config, lib, pkgs, ... }:` and wrap the attrset that follows `in` so the whole body becomes:

```nix
    in
    lib.mkIf (config.desktopShell == "legacy") {
      home.packages = [ pkgs.libnotify ];
      # ... everything that was already here, unchanged ...
    };
```

Only the opening `{` after `in` changes (to `lib.mkIf (config.desktopShell == "legacy") {`). Do not reindent the body; nixfmt is not run on this repo in CI and reindenting makes the diff unreviewable.

- [ ] **Step 6: Guard `modules/desktop/mako.nix`**

```nix
  flake.modules.homeManager.mako =
    { config, lib, ... }:
    lib.mkIf (config.desktopShell == "legacy") {
      services.mako = {
        # ... unchanged ...
      };
    };
```

- [ ] **Step 7: Run the tests**

```bash
git add modules/desktop/desktop-shell.nix
nix eval .#nixosConfigurations.lenovo-p14s.config.home-manager.users.jevin.desktopShell
diff <(nix path-info --derivation .#nixosConfigurations.lenovo-p14s.config.system.build.toplevel) /tmp/claude-1000/noctalia-baseline-drv && echo IDENTICAL
```

Expected: `"legacy"`, then `IDENTICAL`.

Also confirm the switch reaches home-manager in the noctalia variant (helper, `nix eval --raw`, `ATTR` = `sys.config.home-manager.users.jevin.desktopShell`). Expected: `noctalia`.

- [ ] **Step 8: Commit**

```bash
git add modules/desktop/desktop-shell.nix modules/hosts/linux-desktop-base.nix modules/desktop/ashell.nix modules/desktop/mako.nix
git commit -m "desktop-shell: add legacy/noctalia switch, guard ashell and mako"
```

---

### Task 2: Noctalia module, plugins and strict config check

**Files:**
- Create: `modules/desktop/noctalia.nix`
- Create: `modules/desktop/noctalia-plugins/stream-widget.luau`
- Create: `modules/desktop/noctalia-plugins/calendar/plugin.toml`
- Create: `modules/desktop/noctalia-plugins/weather/plugin.toml`
- Modify: `modules/hosts/linux-desktop-base.nix` (import `nixos.noctaliaLock`, `homeManager.noctalia`)

**Interfaces:**
- Consumes: `desktopShell` option (Task 1) in both module systems.
- Produces: `flake.modules.homeManager.noctalia`, `flake.modules.nixos.noctaliaLock`. Plugin ids `jevin/calendar`, `jevin/weather`; widget types `jevin/calendar:meetings`, `jevin/weather:forecast`. `${pkgs.noctalia}/bin/noctalia` is the IPC binary Task 3 calls.

- [ ] **Step 1: Write the shared widget template `modules/desktop/noctalia-plugins/stream-widget.luau`**

```lua
--!nonstrict
-- Bar widget that renders a stream of ashell-style JSON lines:
--   {"text": "...", "alt": "urgent" | "error" | anything}
-- Shared by the calendar and weather plugins. modules/desktop/noctalia.nix
-- substitutes the @...@ tokens with store paths at build time, so the widget
-- needs no per-instance settings (those would trip the strict config check).
--
-- runStream gives Luau no exit callback (v5.1.0 luau_host.cpp), so restarting
-- a dead script lives in the Nix-built stream wrapper, which prints an
-- "alt": "error" line before each restart. That keeps the bar from showing
-- stale text with no marker.

local STREAM = [==[@stream@]==]
local CLICK = [==[@click@]==]
local GLYPH = "@glyph@"

local text = "@name@ loading"
local alert = false

local function render()
  barWidget.setGlyph(GLYPH)
  barWidget.setText(text)
  if alert then
    barWidget.setColor("error")
    barWidget.setGlyphColor("error")
  else
    barWidget.setColor("on_surface")
    barWidget.setGlyphColor("primary")
  end
end

noctalia.runStream(STREAM, function(line)
  local data = noctalia.json.decode(line)
  if type(data) ~= "table" or type(data.text) ~= "string" then
    noctalia.log("@name@: ignoring unparseable line: " .. line)
    return
  end
  text = data.text
  alert = data.alt == "urgent" or data.alt == "error"
  render()
end)

function update()
  noctalia.setUpdateInterval(60000)
  render()
end

function onClick()
  noctalia.runAsync(CLICK)
end
```

- [ ] **Step 2: Write the manifests**

`modules/desktop/noctalia-plugins/calendar/plugin.toml`:

```toml
# Upcoming meetings from waybar/polybar/ashell-calendar.sh (gcalcli).
# widget.luau is generated from ../stream-widget.luau by modules/desktop/noctalia.nix.
id = "jevin/calendar"
name = "Calendar meetings"
version = "1.0.0"
plugin_api = 1
author = "jevin"
license = "MIT"
dependencies = []
description = "Next meetings within the hour; turns red within 10 minutes."

[[widget]]
id = "meetings"
entry = "widget.luau"
```

`modules/desktop/noctalia-plugins/weather/plugin.toml`:

```toml
# Weather from waybar/polybar/openweathermap-forecast.sh.
# widget.luau is generated from ../stream-widget.luau by modules/desktop/noctalia.nix.
id = "jevin/weather"
name = "Weather"
version = "1.0.0"
plugin_api = 1
author = "jevin"
license = "MIT"
dependencies = []
description = "OpenWeatherMap forecast; click for the wttr.in picture."

[[widget]]
id = "forecast"
entry = "widget.luau"
```

- [ ] **Step 3: Create `modules/desktop/noctalia.nix`**

```nix
# Noctalia v5: bar, notifications, launcher, OSD and lock screen for Hyprland.
# Active only when desktopShell = "noctalia" (modules/desktop/desktop-shell.nix).
# Design: docs/superpowers/specs/2026-10-03-noctalia-shell-design.md
#
# CONFIG DRIFT: anything changed in Noctalia's settings GUI is written to
# ~/.local/state/noctalia/settings.toml, and that file WINS over the
# config.toml generated here. "I changed it in Nix and nothing happened" means
# the GUI overrode it. Check with:
#   cat ~/.local/state/noctalia/settings.toml
# Keep Nix as the source of truth: copy keepers in here, then delete the
# override from the state file. Rebuilds never touch the state file.
#
# STRICT CHECK: `noctalia config validate` only WARNS on an unknown key and
# exits 0 (measured on 5.1.0), so home-manager's checkConfig lets typos
# through. strictConfig below fails the build on any "unknown setting".
#
# Not here on purpose:
#   - wallpaper: hyprpaper plus Jevin's art tool own it; Noctalia draws none.
#   - colors: stylix.targets.noctalia writes the palette from base16.
#   - Frigate's 256px notification icons (mako had them): Noctalia has no
#     per-app icon size. Known loss.
{ ... }:
{
  # Lock screen PAM. Noctalia's lock authenticates through the hard-coded
  # "login" PAM service (noctalia-dev/noctalia#3277, open 2026-10-03). With
  # pam_fprintd in that stack a typed password waits ~30s for a finger first.
  # The lock drives fprintd over D-Bus itself, so fingerprint unlock still
  # works. Cost: no fingerprint at a text-console (TTY) login. greetd already
  # has it off (modules/desktop/hyprland.nix).
  flake.modules.nixos.noctaliaLock =
    { config, lib, ... }:
    lib.mkIf (config.desktopShell == "noctalia") {
      security.pam.services.login.fprintAuth = false;
    };

  flake.modules.homeManager.noctalia =
    { config, lib, pkgs, ... }:
    let
      # Same loop as ashell.nix's weather-listen; duplicated until the legacy
      # stack is deleted.
      weatherListen = pkgs.writeShellScript "noctalia-weather-listen" ''
        export KEY_FILE="${config.sops.secrets.openweathermap_api_key.path}"
        while true; do
            weather_output=$(/home/jevin/.config/nixpkgs/waybar/polybar/openweathermap-forecast.sh)
            if [ -n "$weather_output" ]; then
                echo "{\"text\": \"$weather_output\", \"alt\": \"weather\"}"
                sleep 600
            else
                echo "{\"text\": \"Weather unavailable\", \"alt\": \"error\"}"
                sleep 15
            fi
        done
      '';

      # Rerun a listen script forever. Whenever it exits, say so in the bar
      # (alt = error renders red) before retrying, so stale text never sits
      # there unmarked.
      restartLoop =
        name: cmd:
        pkgs.writeShellScript "noctalia-${lib.toLower name}-stream" ''
          while true; do
            ${cmd}
            echo '{"text": "${name} unavailable", "alt": "error"}'
            sleep 15
          done
        '';

      calendarStream = restartLoop "Calendar" "/home/jevin/.config/nixpkgs/waybar/polybar/ashell-calendar.sh";
      weatherStream = restartLoop "Weather" "${weatherListen}";

      calendarClick = "${pkgs.xdg-utils}/bin/xdg-open https://calendar.google.com";
      # URL quoted: unquoted, sh reads `&` as "background this".
      weatherClick = pkgs.writeShellScript "noctalia-weather-click" ''
        ${pkgs.wget}/bin/wget -qO - 'http://wttr.in/.png?m&format=v2' | ${pkgs.feh}/bin/feh - -Z
      '';

      # One read-only plugin directory, registered below as a "path" source
      # (5.1.0 docs: "ideal for Nix-managed plugins"). Both widgets share
      # stream-widget.luau; luau-compile fails the build on a syntax error.
      plugins = pkgs.runCommand "noctalia-plugins-jevin" { nativeBuildInputs = [ pkgs.luau ]; } ''
        mkdir -p $out/calendar $out/weather
        cp ${./noctalia-plugins/calendar/plugin.toml} $out/calendar/plugin.toml
        cp ${./noctalia-plugins/weather/plugin.toml} $out/weather/plugin.toml

        substitute ${./noctalia-plugins/stream-widget.luau} $out/calendar/widget.luau \
          --replace-fail @name@ Calendar \
          --replace-fail @glyph@ calendar \
          --replace-fail @stream@ ${calendarStream} \
          --replace-fail @click@ "${calendarClick}"

        substitute ${./noctalia-plugins/stream-widget.luau} $out/weather/widget.luau \
          --replace-fail @name@ Weather \
          --replace-fail @glyph@ cloud \
          --replace-fail @stream@ ${weatherStream} \
          --replace-fail @click@ ${weatherClick}

        for f in $out/*/widget.luau; do
          luau-compile --null "$f"
        done
      '';

      rawConfig = (pkgs.formats.toml { }).generate "noctalia-config.toml" config.programs.noctalia.settings;
      strictConfig =
        pkgs.runCommand "noctalia-config-strict.toml" { nativeBuildInputs = [ pkgs.noctalia ]; }
          ''
            export HOME=$TMPDIR
            noctalia config validate ${rawConfig} 2>&1 | tee validate.log
            if grep -q "unknown setting" validate.log; then
              echo "noctalia: unknown setting(s) in config.toml, see above" >&2
              exit 1
            fi
            cp ${rawConfig} $out
          '';
    in
    lib.mkIf (config.desktopShell == "noctalia") {
      programs.noctalia = {
        enable = true;
        package = pkgs.noctalia;
        systemd.enable = true;
        # Replaced by strictConfig (see header).
        checkConfig = false;

        settings = {
          wallpaper.enabled = false;

          lockscreen.fingerprint = true;

          bar.default = {
            start = [ "workspaces" ];
            center = [ "meetings" ];
            end = [
              "weather"
              "media"
              "tray"
              "volume"
              "clock"
            ];
          };

          widget = {
            meetings.type = "jevin/calendar:meetings";
            weather.type = "jevin/weather:forecast";
            clock = {
              type = "clock";
              # Same as ashell's tempo.clock_format, in fmt/chrono syntax.
              format = "{:%a %d %b %I:%M %p}";
            };
          };

          # mako used `invisible = 1` for these. Toasts off; history keeps them.
          notification = {
            filter_order = [
              "spotify"
              "slack"
              "obsidian"
              "cloud_drive"
            ];
            filter = {
              spotify = {
                match = "Spotify";
                show_toast = false;
              };
              slack = {
                match = "Slack";
                show_toast = false;
              };
              obsidian = {
                match = "Obsidian";
                show_toast = false;
              };
              cloud_drive = {
                match = "cloud-drive-ui";
                show_toast = false;
              };
            };
          };

          plugins = {
            enabled = [
              "jevin/calendar"
              "jevin/weather"
            ];
            source = [
              {
                name = "jevin";
                kind = "path";
                location = "${plugins}";
                enabled = true;
              }
            ];
          };
        };
      };

      xdg.configFile."noctalia/config.toml".source = lib.mkForce strictConfig;
    };
}
```

- [ ] **Step 4: Wire it into `modules/hosts/linux-desktop-base.nix`**

NixOS `imports`, after `nixos.desktopShell`:

```nix
        nixos.desktopShell
        nixos.noctaliaLock
```

home-manager `imports`, after `homeManager.desktopShell`:

```nix
            homeManager.desktopShell
            homeManager.noctalia
            homeManager.ashell
```

- [ ] **Step 5: Run the legacy test and build the plugins**

```bash
git add modules/desktop/noctalia.nix modules/desktop/noctalia-plugins
diff <(nix path-info --derivation .#nixosConfigurations.lenovo-p14s.config.system.build.toplevel) /tmp/claude-1000/noctalia-baseline-drv && echo IDENTICAL
```

Expected: `IDENTICAL`.

Build the strict config with the noctalia helper, `ATTR` = `sys.config.home-manager.users.jevin.xdg.configFile."noctalia/config.toml".source`.
Expected: a store path ending `-noctalia-config-strict.toml`, and no `unknown setting` lines in the output.

If the build FAILS on an `unknown setting`: the key name in Step 3 is wrong for 5.1.0. Fix it using the validator's message and the v5.1.0 docs at `https://raw.githubusercontent.com/noctalia-dev/noctalia/v5.1.0/docs/user/` (for example `services/notifications.mdx`, `bar/widgets/*.mdx`). Do not delete the key to make the error go away; each key carries a requirement from the spec.

- [ ] **Step 6: Prove the strict check catches typos**

Temporarily add `bogus_key_xyz = true;` inside `settings.wallpaper` in `noctalia.nix`, then rebuild the same `ATTR`.
Expected: FAIL with `wallpaper.bogus_key_xyz: unknown setting` and `noctalia: unknown setting(s) in config.toml`.
Remove the bogus key and rebuild. Expected: PASS.

- [ ] **Step 7: Check the stylix palette and the plugin directory**

`nix eval --impure --json` helper, `ATTR` = `sys.config.home-manager.users.jevin.programs.noctalia.settings.theme`.
Expected: `{"custom_palette":"stylix","mode":"dark","source":"custom"}`.

`cat` the built config.toml from Step 5 and copy the `location` under `[[plugins.source]]`. Then:

```bash
ls -R <location>
/nix/store/vwrdyyaacmsjk1ivswzmaayya9yqkkb8-noctalia-5.1.0/bin/noctalia plugins lint <location>/calendar <location>/weather
grep -c '@' <location>/*/widget.luau
```

Expected: `calendar/{plugin.toml,widget.luau}` and `weather/{plugin.toml,widget.luau}`; lint reports no errors; `grep -c '@'` prints `0` for both (every token substituted).

- [ ] **Step 8: Prove the streams emit JSON and mark failures**

From the built `widget.luau` files, copy the `STREAM` store paths (`grep STREAM <location>/*/widget.luau`). Then:

```bash
timeout 60 <calendar-stream> | head -1 | jq -e '.text and .alt'
timeout 60 <weather-stream> | head -1 | jq -e '.text and .alt'
```

Expected: `true` twice (both use the real gcalcli and OpenWeatherMap setup on this machine; read-only).

Failure marker: run the generated calendar loop with its script swapped for `false`, which exits immediately like a crashed script:

```bash
sed 's#/home/jevin/.config/nixpkgs/waybar/polybar/ashell-calendar.sh#false#' <calendar-stream> > /tmp/claude-1000/dead-stream.sh
timeout 5 sh /tmp/claude-1000/dead-stream.sh | head -1 | jq -e '.alt == "error" and .text == "Calendar unavailable"'
```

Expected: `true`.

- [ ] **Step 9: Commit**

```bash
git add modules/desktop/noctalia.nix modules/desktop/noctalia-plugins modules/hosts/linux-desktop-base.nix
git commit -m "noctalia: add module, calendar and weather plugins, strict config check"
```

---

### Task 3: Binds, brightness OSD and hypridle per shell

**Files:**
- Modify: `modules/desktop/hyprland.nix:76-77` (HM module args), `:113-147` (brightnessAdjust), `:679-680`, `:686`, `:709-717`, `:740`, `:832-838` (hypridle)
- Modify: `modules/desktop/clipboard.nix` (binds)

**Interfaces:**
- Consumes: `desktopShell` (Task 1); `${pkgs.noctalia}/bin/noctalia msg ...` (Task 2 installs the running instance). IPC commands verified on 5.1.0: `volume-up 10`, `volume-down 10`, `volume-mute`, `brightness-osd <0-100>`, `notification-clear-active`, `panel-toggle launcher [context]`, `session lock`. `noctalia dmenu` reads choices on stdin.

Every change below is written so the `"legacy"` branch produces the exact same text as today.

- [ ] **Step 1: Add the switch to the hyprland HM module**

`modules/desktop/hyprland.nix:77`, change `{ pkgs, lib, ... }:` to `{ config, pkgs, lib, ... }:`, and at the top of the `settings = let ... in` block (line 108, before `layoutAware`) add:

```nix
            noctalia = config.desktopShell == "noctalia";
            noctaliaMsg = "${pkgs.noctalia}/bin/noctalia msg";
            # Appended to a brightness command on the SAME line, so legacy
            # renders byte-identical (empty string, no extra newline).
            brightnessOsd = value: lib.optionalString noctalia " && ${noctaliaMsg} brightness-osd ${value}";
```

- [ ] **Step 2: Brightness OSD**

In `brightnessAdjust`, the three set lines become:

```nix
                    ${pkgs.brightnessctl}/bin/brightnessctl set "''${CHANGE#-}%-"${brightnessOsd "$(${pkgs.brightnessctl}/bin/brightnessctl -m | ${pkgs.coreutils}/bin/cut -d, -f4)"}
```

```nix
                    ${pkgs.brightnessctl}/bin/brightnessctl set "''${CHANGE}%+"${brightnessOsd "$(${pkgs.brightnessctl}/bin/brightnessctl -m | ${pkgs.coreutils}/bin/cut -d, -f4)"}
```

```nix
                  ${pkgs.ddcutil}/bin/ddcutil --bus $BUS --noverify setvcp 10 $NEW${brightnessOsd "$NEW"}
```

(`brightnessctl -m` prints `device,class,raw,NN%,max`; field 4 is `NN%`, which `brightness-osd` accepts.)

Update the comment above the 232/233 binds:

```nix
              # Brightness stays on brightnessAdjust: it's cursor-aware and drives
              # external monitors via DDC/ddcutil, which the shells' brightness
              # IPC can't do. On noctalia it then calls `brightness-osd` with the
              # new value for an OSD; on legacy there is no brightness OSD.
```

Comments are not part of the generated config, so this does not affect the legacy derivation.

- [ ] **Step 3: Launcher, lock, volume and notification binds**

Replace the lines, keeping their positions in the list:

```nix
              (if noctalia then "$mod, R, exec, ${noctaliaMsg} panel-toggle launcher" else "$mod, R, exec, rofi -modes run -show run")
              (if noctalia then "$mod, C, exec, ${noctaliaMsg} panel-toggle launcher '/calc '" else "$mod, C, exec, rofi -modes calc -show calc")
```

```nix
              (if noctalia then "$mod, P, exec, ${noctaliaMsg} session lock" else "$mod, P, exec, ${pkgs.hyprlock}/bin/hyprlock")
```

```nix
              # Media controls
              # Volume keys route through the shell's IPC so its OSD overlay
              # shows (the shell performs the PipeWire change itself). Step 10
              # matches ashell's settings.volume_step in modules/desktop/ashell.nix.
              (if noctalia then ", XF86AudioMute, exec, ${noctaliaMsg} volume-mute" else ", XF86AudioMute, exec, ${pkgs.ashell}/bin/ashell msg volume-toggle-mute")
              # Mic mute keeps the custom mute-all-sources script (no OSD).
              ", XF86AudioMicMute, exec, ${micMuteAll}"
              (if noctalia then ", XF86AudioLowerVolume, exec, ${noctaliaMsg} volume-down 10" else ", XF86AudioLowerVolume, exec, ${pkgs.ashell}/bin/ashell msg volume-down")
              (if noctalia then ", XF86AudioRaiseVolume, exec, ${noctaliaMsg} volume-up 10" else ", XF86AudioRaiseVolume, exec, ${pkgs.ashell}/bin/ashell msg volume-up")
```

```nix
              # Notifications. Noctalia has no "dismiss newest": this clears
              # every visible toast (they stay in control-center history).
              (if noctalia then "$mod, N, exec, ${noctaliaMsg} notification-clear-active" else "$mod, N, exec, ${pkgs.mako}/bin/makoctl dismiss")
```

Also update line 95's comment to `# Required for hyprland-session.target (ashell and Noctalia start from it)`.

- [ ] **Step 4: Clipboard and emoji binds in `modules/desktop/clipboard.nix`**

Change args to `{ config, pkgs, ... }:` and the bind list to:

```nix
      wayland.windowManager.hyprland.settings.bind =
        let
          noctalia = config.desktopShell == "noctalia";
          noctaliaBin = "${pkgs.noctalia}/bin/noctalia";
        in
        [
          (if noctalia then "$mod, V, exec, ${pkgs.cliphist}/bin/cliphist list | ${noctaliaBin} dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy" else "$mod, V, exec, ${pkgs.cliphist}/bin/cliphist list | rofi -dmenu -p clipboard | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy")
          (if noctalia then "$mod, period, exec, ${noctaliaBin} msg panel-toggle launcher '/emo '" else "$mod, period, exec, rofi -modes emoji -show emoji")
        ];
```

`programs.rofi` stays enabled in both modes until the legacy stack is deleted (keeps rollback a pure switch flip).

- [ ] **Step 5: hypridle `lock_cmd` in `flake.modules.homeManager.hyprSession`**

Replace the `lock_cmd` line with a conditional attr merged into `general` (attrsets render sorted, so legacy output is unchanged):

```nix
          general = {
            unlock_cmd = "hyprctl dispatch dpms on";
            # ... before_sleep_cmd, comments, after_sleep_cmd, inhibit_sleep unchanged ...
          }
          # On noctalia, Noctalia itself answers logind's Lock signal
          # ("`loginctl lock-session` uses the same path when Noctalia is
          # running", v5.1.0 IPC docs). A lock_cmd here would open a second
          # locker, so it only exists on legacy.
          // lib.optionalAttrs (config.desktopShell == "legacy") {
            lock_cmd = "pidof hyprlock || hyprlock";
          };
```

- [ ] **Step 6: Run the tests**

```bash
diff <(nix path-info --derivation .#nixosConfigurations.lenovo-p14s.config.system.build.toplevel) /tmp/claude-1000/noctalia-baseline-drv && echo IDENTICAL
```

Expected: `IDENTICAL`. If not, a legacy string changed. Find it by diffing the generated Hyprland config against the last commit (no stash needed; `?rev=` evaluates committed HEAD):

```bash
A='nixosConfigurations.lenovo-p14s.config.home-manager.users.jevin.xdg.configFile."hypr/hyprland.conf".text'
diff <(nix eval --raw "git+file://$PWD?rev=$(git rev-parse HEAD)#$A") <(nix eval --raw ".#$A")
```

Repeat with `...services.hypridle.settings` (`--json`) if the Hyprland config matches.

Noctalia variant, `nix eval --impure --raw` helper, `ATTR` = `sys.config.home-manager.users.jevin.xdg.configFile."hypr/hyprland.conf".text`, piped to checks:

```bash
<helper> | grep -E '^bind=' | grep -cE 'rofi|ashell|makoctl|hyprlock'
<helper> | grep -E '^bind=' | grep -c 'noctalia'
```

Expected: `0`, then `9` (R, C, P, mute, down, up, N, V, period).

Brightness script: `<helper> | grep -oE '/nix/store/[^ ]*brightness-adjust' | head -1 | xargs cat | grep -c brightness-osd`.
Expected: `3`.

hypridle: helper with `ATTR` = `sys.config.home-manager.users.jevin.services.hypridle.settings.general`, `--json`, piped to `jq 'has("lock_cmd")'`.
Expected: `false`. Same attribute without the helper (legacy) → `true`.

Full noctalia system builds: helper with `ATTR` = `sys.config.system.build.toplevel` (`nix build`, no switch).
Expected: a store path, exit 0.

- [ ] **Step 7: Commit**

```bash
git add modules/desktop/hyprland.nix modules/desktop/clipboard.nix
git commit -m "hyprland: route binds, brightness OSD and lock through desktopShell"
```

---

### Task 4: Flip the switch (user-run live test)

**Files:**
- Modify: `modules/hosts/linux-desktop-base.nix` (one line)

This task changes the running system. The executor does Steps 1-3 and STOPS. Steps 4-6 are the user's, run when the other worktree's agent is done.

- [ ] **Step 1: Set the switch**

In the inner NixOS module of `linux-desktop-base.nix`, next to `system.stateVersion`:

```nix
      # Desktop shell (modules/desktop/desktop-shell.nix). "legacy" rolls back.
      desktopShell = "noctalia";
```

- [ ] **Step 2: Build only**

```bash
nix build --no-link --print-out-paths .#nixosConfigurations.lenovo-p14s.config.system.build.toplevel
```

Expected: a store path, exit 0. Do NOT switch.

- [ ] **Step 3: Commit and hand off**

```bash
git add modules/hosts/linux-desktop-base.nix
git commit -m "linux-desktop: switch desktop shell to noctalia"
```

Tell the user the branch is ready and give them Steps 4-6.

- [ ] **Step 4 (user): Switch from the worktree**

`rebuildhm` builds the main checkout, so it would not include this branch. From the worktree:

```bash
cd ~/.config/nixpkgs/.claude/worktrees/noctalia-shell
sudo nixos-rebuild switch --flake ".#$(hostname)"
```

Then log out and back in (Hyprland reads exec-once and binds at start).

- [ ] **Step 5 (user): Run the acceptance checklist**

The checklist at the top of the spec, every box.

- [ ] **Step 6 (user): Roll back if anything breaks**

Set `desktopShell = "legacy";`, then the same `nixos-rebuild switch` from the worktree. If only the sudo-fingerprint item fails (#4591, fixed upstream 2026-10-02, not in 5.1.0), report it instead: the fix is an overlay patch on `pkgs.noctalia` or the upstream flake, decided then.

---

## Follow-up (not part of this plan)

After about two weeks clean: merge the branch, then delete `ashell.nix`, `mako.nix`, the rofi config and binds, the hyprlock config, the ashell tray watchdog and the yazi tray note (`modules/shell/yazi.nix:186-194`), and `desktop-shell.nix` with every `if noctalia` branch. Port the TimeTagger widget as a third `stream-widget.luau` instance.
