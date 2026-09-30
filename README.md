# Begonecia (rootless)

A **rootless port** of [**BegoneCIA** by Eva (Nepeta)](https://github.com/larygwil/BegoneCIA) for
Dopamine on iOS 15–16. (Nepeta's own repository is no longer online; the link is an
unofficial mirror of the original source.)

It's a Control Center toggle that silences the **microphone, camera and location** system-wide.
While it's on, apps don't get a permission error, they just get nothing: silent mic audio,
no camera input, no location updates.

Install it from **[John's Repo](https://jond-ie.github.io/repo/)** (Sileo / Zebra:
`https://jond-ie.github.io/repo/`). Bugs and requests go to the repo's
[Issues](https://github.com/Jond-ie/repo/issues).

## Credits

- **Eva (Nepeta)** wrote the original BegoneCIA and the core technique: silencing the mic
  inside `mediaserverd`, nulling `CLLocationManager` delegates, and withholding
  `AVCaptureSession` inputs. All credit for the idea and the original code is hers.
- **John d_ie** did the rootless / iOS 16 port: porting research, on-device testing and
  debugging on an iPhone 8 Plus (A11) running iOS 16.7 with Dopamine.
- The port was **AI-assisted**: much of the code was written with Claude Code (Anthropic),
  directed, tested and verified on-device by John d_ie.

Licensed MIT, same as the original; see [LICENSE](LICENSE). Nepeta's copyright is kept
unchanged, and the license also ships inside the package.

## What changed for rootless / iOS 16

**Build and packaging**
- `ARCHS = arm64 arm64e`, `TARGET = iphone:clang:latest:15.0` (armv7/armv7s dropped).
- Built with `THEOS_PACKAGE_SCHEME=rootless`: everything installs under `/var/jb`, and the
  package architecture is `iphoneos-arm64`.
- Hooks run through **ellekit** (Dopamine's hook engine). Depends on `ellekit`,
  `com.opa334.ccsupport` (CCSupport) and `ws.hbang.common` (Cephei).
- Package id `com.johndie.begonecia`, with `Conflicts`/`Replaces: me.nepeta.begonecia`.

**SDK fixes (iOS 16.5 SDK)**
- `kNilOptions` → `CFNotificationSuspensionBehaviorCoalesce` for the Darwin notification observer.
- `#import <UIKit/UIKit.h>` added to the bundled Control Center headers.
- `Frameworks/ControlCenterUIKit.tbd` patched to include `arm64e` (SpringBoard is arm64e on A12+).

**Behavior fixes found on-device (iOS 16)**
- **State didn't reach sandboxed apps.** Cephei 2 keeps preferences under `/var/jb`, which
  apps and `mediaserverd` can't read. The on/off state is now mirrored into a Darwin notify
  state (`notify_set_state`) that every process can read; SpringBoard re-seeds it at launch.
- **Maps bypassed the location block.** MapKit passes its delegate to the
  `CLLocationManager` designated initializer instead of `-setDelegate:`, so that initializer
  is hooked too.
- **The mic produced noise, not silence.** The AGC buffer is now zeroed after processing
  (`memset`) instead of being swapped for an uninitialised buffer. Audio read from the
  RemoteIO / VoiceProcessingIO input bus is also zeroed in apps (covers AVAudioEngine).

## Compatibility

Tested only on an **iPhone 8 Plus (A11, arm64)**, iOS 16.7, Dopamine. The package also
contains an arm64e build for A12 and newer devices, but it's built with the older arm64e
ABI and **hasn't been tested on an arm64e device**. Reports from A12+ devices are very
welcome in [Issues](https://github.com/Jond-ie/repo/issues).

## Known caveat: the mic AGC subtype

The `mediaserverd` mic silencer keys on the voice-processing AGC audio units (`'agcc'` /
`'agc2'`). On the test device (iPhone 8 Plus, iOS 16.7), recording runs through `'agc2'`
and the mic is silent. Other devices or iOS versions may use a different chain. If camera
and location are blocked but the mic still records, this is the first thing to check:
build with `BC_DEBUG=1` (below) and look for the `AudioUnitProcess` subtypes in the log.
The input-bus zeroing in apps is a second layer, but it doesn't cover every audio path.

## Building

Requires [Theos](https://theos.dev) with the rootless scheme.

```bash
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

The package is written to `packages/`. To install directly, set `THEOS_DEVICE_IP` and run
`make package install FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`.

Debug logging (view on-device with `oslog`):

```bash
make package install THEOS_PACKAGE_SCHEME=rootless BC_DEBUG=1
```

`PORT-NOTES.md` has the working notes from the port.
