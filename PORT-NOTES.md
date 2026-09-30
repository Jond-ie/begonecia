# BegoneCIA — rootless port notes

This is a faithful **rootless port** of Nepeta's BegoneCIA (MIT, © 2018 Eva/Nepeta),
not a from-scratch tweak. The original iOS 10/11 source is used as-is where it can
be; only what rootless + iOS 16 requires was changed. My earlier from-scratch
`Begonecia` is superseded by this — it used the wrong hook points and did nothing.

## Why the original works and my first attempt didn't

| Target | Proven approach (this port) | My broken first attempt |
|---|---|---|
| **Mic** | Hooks `AudioUnitProcess` **inside `mediaserverd`** and zeroes the AGC input unit's buffer (`'agcc'`/`'agc2'`). Catches every app, any audio API. | Only no-op'd `AVCaptureSession -startRunning`. Missed the mic path entirely. |
| **Location** | Nulls the `CLLocationManager` **delegate** (stores the real one to restore). No delegate → no callbacks, reversible live. | No-op'd individual `start*` methods; missed already-running managers. |
| **Camera** | Suppresses `AVCaptureSession -addInput:` (tracks inputs, re-adds on disable). | No-op'd `startRunning`; many apps unaffected. |
| **Injection** | `Executables = ("mediaserverd"); Bundles = ("com.apple.UIKit")` | UIKit only → `mediaserverd` never injected. |
| **Reload** | `postinst` kills `mediaserverd` so the audio hook loads. | none. |

## What I changed for rootless / iOS 16

- **Build settings** (all Makefiles): `ARCHS = arm64 arm64e`, `TARGET = …latest:15.0`.
  Dropped armv7/armv7s.
- **Packaging**: build with `THEOS_PACKAGE_SCHEME=rootless`; install paths get the
  `/var/jb` prefix automatically. `control` → `iphoneos-arm64`, rootless deps.
- **Dependencies**: `ellekit` (Dopamine's hook engine, replaces mobilesubstrate),
  `com.opa334.ccsupport` (you have it), `ws.hbang.common` (Cephei 2.0, for the prefs;
  install it from Chariz first or dpkg leaves the package unconfigured).
- **CC private headers**: taken straight from the repo (`Module/ControlCenterUIKit/`),
  so nothing needs class-dumping off the device.
- **`ControlCenterUIKit.tbd`**: patched to advertise `arm64e` as well, since A12+
  system processes (SpringBoard, mediaserverd) are arm64e. Symbols are unchanged.
- The tweak source itself has **no filesystem path literals**, so no `/var/jb`
  path-rewriting was needed there.

## What iOS 16 / rootless actually required (verified on device, iOS 16.7, A11)

The first straight port installed and the CC tile worked, but nothing was blocked.
Live `oslog` tracing found three problems:

1. **State never reached the hooks.** Cephei 2 (rootless) keeps the plist at
   `/var/jb/var/mobile/Library/Preferences/`, which sandboxed processes can't read:
   `HBPreferences` returned 0 in mediaserverd, Camera and Maps, and raw
   `CFPreferences` was blocked in Maps. **Fix:** the live state is mirrored into a
   Darwin notify state (`me.nepeta.begonecia/State`, `notify_set_state` /
   `notify_get_state`), which any process can read. The Cephei plist remains the
   persistent copy; SpringBoard re-seeds the notify state from it at launch and
   holds the name open (notifyd drops the state once no process is registered).
   See `BCCommon.m`.
2. **Maps bypasses `-setDelegate:`.** MapKit creates `CLLocationManager` via the
   `init…delegate:onQueue:` family, which all funnel into
   `-initWithEffectiveBundleIdentifier:bundlePath:websiteIdentifier:delegate:silo:`.
   That initializer is now hooked too (delegate withheld while active, restored live).
3. **Mic silencing produced garbage, not silence.** `'agc2'` *is* still in the
   mediaserverd mic chain on iOS 16, but the original code swapped in an
   uninitialised `malloc`'d buffer on the realtime thread (and leaked it per
   callback). Now: let the AGC run, then `memset` its in-place output to zero.
   Added a second layer: `AudioUnitRender` on RemoteIO / VoiceProcessingIO **bus 1**
   (the mic element) is zeroed in every injected process (catches AVAudioEngine,
   e.g. Voice Memos).

Camera (`-addInput:` suppression) worked unchanged once the state was fixed.
Tracked sessions/managers are now held in weak, lock-guarded `NSHashTable`s.

Verified: Camera viewfinder blocked, Maps gets no location, Voice Memos records
silence; toggling off restores all three live.

## Debugging

Debug logging is compiled out by default. To trace on device:

```bash
make package install THEOS_PACKAGE_SCHEME=rootless BC_DEBUG=1
ssh root@$THEOS_DEVICE_IP '/var/jb/usr/bin/oslog' | grep BegoneCIA   # apt install oslog
```

It logs the state each process reads, which hooks fire, and every audio unit
type/subtype mediaserverd and apps process (first sighting only).

## Known build warnings (harmless)

- `built with an incompatible arm64e ABI compiler`: the Linux toolchain emits the
  old arm64e ABI. **Correction:** the test device (iPhone 8 Plus, A11) is arm64, not
  arm64e, so only the arm64 slice was ever loaded. Whether the old-ABI arm64e slice
  loads on A12+ devices is untested; Theos's documentation says old-ABI arm64e
  binaries don't load into arm64e processes on iOS 14+.
- `ControlCenterUIKit.tbd … out of sync`: ld message only; links correctly.

## Build & deploy

```bash
cd Begonecia-rootless
make clean
make package install THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1   # needs THEOS_DEVICE_IP set
ssh root@$THEOS_DEVICE_IP 'killall -9 SpringBoard'     # respring so the CC tile appears
```

`postinst` already kills `mediaserverd` on install so the audio hook loads; the
respring is only needed for the Control Center tile to show up. Add the tile in
Settings → Control Center if it isn't in the active set.

Test: pull the tile (or `/var/jb/usr/local/bin/begonecia on`; it is not on the default
SSH PATH), then open Voice Memos / Camera / Maps. Apps already running pick up
toggles live.

## Attribution

Original: https://github.com/Nepeta/BegoneCIA — MIT. `LICENSE` retained. This port
keeps the original bundle id and code; credit for the actual technique is Nepeta's.
