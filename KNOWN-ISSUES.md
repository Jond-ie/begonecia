# Known issues (Begonecia)

## Siri still hears the mic while Begonecia is on — FIXED in 0.2.0-rootless4 (confirmed by voice test 2026-10-03)
- Reported 2026-09-30 on iPhone 8 Plus, iOS 16.7, with Begonecia 0.2.0-rootless1 enabled:
  holding Home for Siri, Siri responds to speech.
- Unverified hypothesis: Siri captures audio in its own daemons (corespeechd / assistantd),
  which Begonecia doesn't inject into; the in-app RemoteIO bus-1 zeroing only covers UIKit
  apps, and the mediaserverd hook only zeroes the 'agcc'/'agc2' AGC units, which Siri's
  capture chain may not use.
- Next step: probe which process/audio unit Siri's capture runs through (oslog + a
  log-only AudioUnitRender/AudioUnitProcess hook in those daemons), then fix for the next release.
- Cause (found 2026-10-02 on the iPhone 7, iOS 15.8.6): Siri captures in corespeechd via
  AudioQueueNewInput (16 kHz mono 16-bit PCM); the mediaserverd chain for it has no agcc/agc2
  (hkip bus 1, nbeq, bem2, sila, happ, voli). Raw input rms 64-103 with Begonecia on.
- Fix: AudioQueue input callbacks wrapped (PCM16 zeroed while active), corespeechd + assistantd
  added to the filter.

## Fixed in 1.0.1~dev2 (2026-10-15, found in the user's 11 Pro crash logs, iOS 18.6.2)
- parsecd crashed (dispatch_assert_queue): the "denied" answer to -requestLocation was delivered on the main queue;
  managers made with ...onQueue: (parsecd's Swift code) assert their own queue. Now delivered through the manager's
  CLSilo (CLLocationManagerInternal fSilo, -async:), main queue only as a fallback.
- Snapchat crashed (NSInvalidArgumentException in -[AVCaptureSession addInput:]) when Begonecia was turned off: the
  re-add loop put back inputs the session already had or couldn't take. Now skips those (inputs / canAddInput:) and
  catches the exception. SE 2 check: Camera open, toggled on/off 3x, no crash.
