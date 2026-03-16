# Hyprlock Fingerprint Broken After Suspend/Resume

## Summary

Fingerprint unlock never works after suspend/resume on hyprlock. The root cause
is a bug in hyprlock's `src/auth/Fingerprint.cpp` where the `PrepareForSleep`
handler doesn't clean up device state before suspend, leaving a stale D-Bus
device proxy that silently fails on resume.

## Symptoms

- After suspend/resume, touching the fingerprint reader does nothing
- Hyprlock logs show `PrepareForSleep (start: true)` then `(start: false)`
  immediately after claiming the device
- On exit: `WARN: fprint: could not release device, Device was not claimed before use`
- User must type password every time after resume
- Fingerprint works fine on idle lock (no suspend involved)

## The Bug (hyprlock src/auth/Fingerprint.cpp)

### PrepareForSleep(true) — entering suspend

```cpp
m_sDBUSState.sleeping = start;  // sets sleeping = true
if (!m_sDBUSState.sleeping && !m_sDBUSState.verifying)
    startVerify();
// ^ condition is false, so nothing happens
```

That's all it does. It does NOT:
- Call `stopVerify()` to end the active verification session
- Call `releaseDevice()` to release the fprintd device claim
- Clear `m_sDBUSState.device` (the D-Bus device proxy)

Meanwhile, the kernel powers off the USB fingerprint sensor during suspend,
invalidating fprintd's internal device state.

### PrepareForSleep(false) — resuming from suspend

```cpp
m_sDBUSState.sleeping = false;
if (!m_sDBUSState.sleeping && !m_sDBUSState.verifying)
    startVerify();
```

This calls `startVerify()`, but:

```cpp
void CFingerprint::startVerify(bool isRetry) {
    m_sDBUSState.verifying = true;
    if (!m_sDBUSState.device) {   // <-- device proxy still set from before!
        if (!createDeviceProxy())
            return;
        claimDevice();
        return;
    }
    // Falls through to VerifyStart on the STALE proxy
}
```

Since `m_sDBUSState.device` was never cleared, it skips the fresh
`createDeviceProxy()` and `claimDevice()` calls. It tries to call
`VerifyStart` on a stale proxy pointing to a device that was USB-reset.
fprintd rejects this because the device was never properly claimed in the
new session.

### What the fix should be

```cpp
// In the PrepareForSleep signal handler:
if (start) {  // entering suspend
    stopVerify();
    releaseDevice();
    m_sDBUSState.device = nullptr;  // force full re-init on wake
}
if (!start && !m_sDBUSState.verifying) {  // resuming
    startVerify();  // will now go through createDeviceProxy -> claimDevice
}
```

## Timeline From Logs (observed on Lenovo P14s, Synaptics 06cb:00f9)

```
14:27:30  Resume from suspend
14:27:30  hypridle runs: dpms on && sleep 1 && hyprctl reload
14:27:50  hyprlock starts, renders in 84ms
14:27:50  fprint: claimed device
14:27:50  fprint: started verifying (right-index-finger)
14:27:50  fprint: PrepareForSleep (start: true)   <-- stale D-Bus signal
14:27:50  fprint: PrepareForSleep (start: false)   <-- replayed on resume
14:27:50  PAM_PROMPT: Password:                    <-- fingerprint silently broken
14:27:50  auth: authenticated for hyprlock         <-- user typed password
14:27:50  WARN: could not release device (not claimed)
```

Fingerprint verification started but PrepareForSleep events immediately
disrupted the device claim. The sensor never actually scanned.

## Upstream Issues

- **hyprwm/hyprlock#577** — "Fingerprint auth breaks completely on suspend/resume"
  - Status: Closed (Dec 2024), but the fix is incomplete
  - The merged fix improved some cases but the stale device proxy problem remains
- **hyprwm/hyprlock#538** — "Way to toggle or manually prompt fingerprint reading"
  - Status: Open, stale (Nov 2024)
  - Separate issue: first touch to wake DPMS is consumed as a failed scan
- **hyprwm/hyprlock#702** — "Fingerprint device disconnects after long idle"
  - USB autosuspend powers off the sensor; fixed in PR #722
- **hyprwm/hyprlock#953** — "Missing /etc/pam.d/hyprlock"
  - NixOS needs `security.pam.services.hyprlock = {};`
- **NixOS/nixpkgs#432276** — Stale PAM sessions after fprintd restart on resume

## Current Workarounds (in this repo, commit 86c2b00)

1. **`powerManagement.powerDownCommands` stops fprintd before suspend**
   - Helps fprintd start fresh, but hyprlock still holds a stale device proxy
   - File: `modules/desktop/hyprland.nix`

2. **`inhibit_sleep = 3`** in hypridle
   - Waits for hyprlock to fully lock before allowing suspend
   - Reduces race window but doesn't fix the stale proxy

3. **USB autosuspend disabled** for Synaptics reader via udev rule
   - Prevents sensor from being powered off during idle
   - File: `modules/hardware/lenovo-p14s.nix`

4. **`security.pam.services.hyprlock.fprintAuth = false`**
   - Creates proper PAM service (no more fallback to /etc/pam.d/su)
   - Disables PAM-level fingerprint to avoid double-prompting with D-Bus API

5. **`fprint-dpms-wake` systemd user service**
   - Watches fprintd VerifyStatus D-Bus signals to wake DPMS on touch
   - Workaround for the screen being off when you touch the sensor

## Possible Solutions to Explore

### Option A: Upstream PR
Fix the `PrepareForSleep` handler in hyprlock to properly clean up device
state. Small, surgical change. See "What the fix should be" above.

### Option B: Kill hyprlock on resume, let hypridle relaunch it
Instead of reusing the hyprlock instance that survived suspend (with its
stale fprint state), kill it on resume and let `lock_cmd` start a fresh one:

```nix
after_sleep_cmd = "pkill hyprlock; hyprctl dispatch dpms on && sleep 1 && hyprctl reload";
# lock_cmd will relaunch: "pidof hyprlock || hyprlock"
```

Risk: brief moment where the session is unlocked during the kill/relaunch gap.
The Wayland ext-session-lock protocol should show a solid color during this
gap, but it's not ideal.

### Option C: Switch to PAM-based fingerprint auth
Use `auth.fingerprint.enabled = false` in hyprlock and rely on
`pam_fprintd.so` via the PAM service instead. Avoids the D-Bus
PrepareForSleep issue entirely, but PAM has a 99-second timeout after which
fingerprint stops working until password is entered.

### Option D: Delay hyprlock's fprint init after resume
Add a sleep or D-Bus wait in the `after_sleep_cmd` before hyprlock starts
fprint verification. Doesn't fix the stale proxy but might let the
PrepareForSleep signals drain before hyprlock processes them.

## Hardware

- Lenovo ThinkPad P14s Gen 6 AMD
- Synaptics fingerprint reader (06cb:00f9), USB bus 003
- NixOS with Hyprland, hyprlock 0.9.2+
