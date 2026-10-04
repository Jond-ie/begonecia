# Begonecia (rootless)

A **rootless port** of [**BegoneCIA** by Eva (Nepeta)](https://github.com/larygwil/BegoneCIA) for
Dopamine on iOS 15–17. (Nepeta's own repository is no longer online; the link is an
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
- **Siri still heard the mic** (fixed in `0.2.0-rootless4`). Siri records in `corespeechd`
  through an AudioQueue (16 kHz, 16-bit PCM), which Begonecia didn't inject into, and its
  `mediaserverd` chain doesn't use the AGC units silenced above. AudioQueue input callbacks
  are now wrapped and handed silence while Begonecia is on, and `corespeechd`/`assistantd`
  are in the filter. This also covers apps that record through AudioQueue.
- **iOS 17 moved audio processing** (fixed in `0.2.0-rootless5`). On iOS 17 the audio server's
  work runs in a new daemon, `audiomxd` (next to `mediaserverd`), so it's now in the filter. Siri's
  capture on iOS 17 still goes through `corespeechd`'s AudioQueue, which the rootless4 fix covers.

## Compatibility

Tested with Dopamine on an **iPhone SE (2nd gen, A13, arm64e)** with iOS 17.5.1, an
**iPhone 8 Plus (A11)** with iOS 16.7 and an **iPhone 7 (A10)** with iOS 15.8.6.

**A12 and newer (arm64e): confirmed** since `0.2.0-rootless5`. On the iPhone SE (2nd gen),
iOS 17.5.1, an app recording through AVAudioEngine gets exact zeros with Begonecia on and
normal audio with it off, and Siri's input buffers reach it as silence. (Builds up to
`0.2.0-rootless1` put A12+ devices into safe mode: their arm64e slice used the old,
unversioned pointer-authentication ABI. Current builds are made with Xcode's clang.)

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

**Your toolchain must emit the versioned arm64e ABI.** Xcode's clang does. Some Linux
toolchains (e.g. open-source Apple clang 13) don't: they build an arm64e slice marked `0x2`
that crashes A12+ devices, and the linker warns `built with an incompatible arm64e ABI
compiler`. Check the result: every binary's arm64e slice should have cpusubtype
`0x80000002`. If your toolchain can't do that, build `ARCHS=arm64` only. Release packages
are built on a macOS GitHub Actions runner (Xcode clang, iPhoneOS 16.5 SDK).

The package is written to `packages/`. To install directly, set `THEOS_DEVICE_IP` and run
`make package install FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless`.

Debug logging (view on-device with `oslog`):

```bash
make package install THEOS_PACKAGE_SCHEME=rootless BC_DEBUG=1
```

`PORT-NOTES.md` has the working notes from the port.
