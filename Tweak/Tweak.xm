#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <os/lock.h>
#import "../BCCommon.h"

#ifdef BC_PROBE
// Dev builds: report through Darwin notify state, which sandboxed daemons can set
// (oslog doesn't show tweaks' log lines on iOS 17). Read with
//   notifyutil -g com.johndie.begonecia.probe.<process>.<key>
#import <notify.h>
static void BCProbe(const char *key, uint64_t value) {
    char name[160];
    snprintf(name, sizeof(name), "com.johndie.begonecia.probe.%s.%s", getprogname(), key);
    // State only lasts while a registration holds the name: keep one per key.
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    static CFMutableDictionaryRef tokens;
    os_unfair_lock_lock(&lock);
    if (!tokens) tokens = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
    CFStringRef key2 = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);
    int token = (int)(intptr_t)CFDictionaryGetValue(tokens, key2) - 1;
    if (token < 0 && notify_register_check(name, &token) == NOTIFY_STATUS_OK) CFDictionarySetValue(tokens, key2, (const void *)(intptr_t)(token + 1));
    if (token >= 0) notify_set_state(token, value);
    CFRelease(key2);
    os_unfair_lock_unlock(&lock);
}
// The n-th new sighting goes to key s<n> as its two codes (b << 32 | c).
static void BCProbeSighting(int index, uint32_t type, uint32_t subtype, uint32_t tag) {
    char key[32];
    snprintf(key, sizeof(key), "s%d", index);
    BCProbe(key, ((uint64_t)type << 32) | subtype); (void)tag;
    BCProbe("n", index + 1);
}
#endif

#ifdef BC_DEBUG
#import <objc/runtime.h>
#define BCLog(fmt, ...) NSLog(@"[BegoneCIA] %s[%d] " fmt, getprogname(), getpid(), ##__VA_ARGS__)
#define BCFourCC(x) (char)((x)>>24), (char)((x)>>16), (char)((x)>>8), (char)(x)
static BOOL bcIsDebugTarget(void) {
    const char *n = getprogname();
    return !strcmp(n, "mediaserverd") || !strcmp(n, "audiomxd") || !strcmp(n, "corespeechd") || !strcmp(n, "assistantd") || !strcmp(n, "Camera") || !strcmp(n, "Maps") || !strcmp(n, "VoiceMemos") || !strcmp(n, "SpringBoard");
}
// Returns YES the first time a given (a, b, c) triple is seen in this process.
static BOOL bcFirstSighting(uint32_t a, uint32_t b, uint32_t c) {
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    static uint32_t seen[128][3];
    static int nseen = 0;
    BOOL isNew = YES;
    os_unfair_lock_lock(&lock);
    for (int i = 0; i < nseen; i++) {
        if (seen[i][0] == a && seen[i][1] == b && seen[i][2] == c) { isNew = NO; break; }
    }
    int index = -1;
    if (isNew && nseen < 128) { seen[nseen][0] = a; seen[nseen][1] = b; seen[nseen][2] = c; index = nseen++; }
    os_unfair_lock_unlock(&lock);
#ifdef BC_PROBE
    if (index >= 0) BCProbeSighting(index, b, c, a & 0xffff);
#endif
    return isNew;
}
#else
#define BCLog(...)
#endif

static BOOL bcActive = false;

// Weak so tracked sessions/managers can still be deallocated; guarded because
// they are created on arbitrary threads.
static os_unfair_lock bcTrackLock = OS_UNFAIR_LOCK_INIT;
static NSHashTable *bcCaptureSessions;
static NSHashTable *bcLocationManagers;

static void bcTrack(NSHashTable *table, id obj) {
    os_unfair_lock_lock(&bcTrackLock);
    [table addObject:obj];
    os_unfair_lock_unlock(&bcTrackLock);
}

static NSArray *bcTracked(NSHashTable *table) {
    os_unfair_lock_lock(&bcTrackLock);
    NSArray *objs = [table allObjects];
    os_unfair_lock_unlock(&bcTrackLock);
    return objs;
}

static void bcSilence(AudioBufferList *ioData) {
    if (!ioData) return;
    for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        if (ioData->mBuffers[i].mData) memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
    }
}

// mediaserverd: the voice-processing AGC units sit in every mic input chain.
// Let them run, then zero their (in-place) output.
%hookf(OSStatus, AudioUnitProcess, AudioUnit unit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames, AudioBufferList *ioData) {
    OSStatus result = %orig;
    if (bcActive) {
        AudioComponentDescription unitDescription = {0};
        AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit), &unitDescription);
#ifdef BC_DEBUG
        if (bcFirstSighting('AUPr', unitDescription.componentType, unitDescription.componentSubType))
            BCLog(@"AudioUnitProcess: type='%c%c%c%c' subtype='%c%c%c%c'", BCFourCC(unitDescription.componentType), BCFourCC(unitDescription.componentSubType));
#endif

        // Replaces microphone input with silence.
        if (unitDescription.componentSubType == 'agcc' || unitDescription.componentSubType == 'agc2') {
            bcSilence(ioData);
        }
    }
    return result;
}

// Any process: pulling from bus 1 (the input element) of RemoteIO /
// VoiceProcessingIO is reading the microphone. Zero what comes back.
%hookf(OSStatus, AudioUnitRender, AudioUnit unit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    OSStatus result = %orig;
    if (bcActive && inOutputBusNumber == 1) {
        AudioComponentDescription d = {0};
        AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit), &d);
#ifdef BC_DEBUG
        if (bcFirstSighting(d.componentType, d.componentSubType, 'mute'))
            BCLog(@"AudioUnitRender bus 1: type='%c%c%c%c' subtype='%c%c%c%c'", BCFourCC(d.componentType), BCFourCC(d.componentSubType));
#endif
        if (d.componentType == kAudioUnitType_Output && (d.componentSubType == kAudioUnitSubType_RemoteIO || d.componentSubType == kAudioUnitSubType_VoiceProcessingIO)) {
            bcSilence(ioData);
        }
    }
    return result;
}

// AudioQueue recorders (Siri's corespeechd, Voice Memos-style apps): wrap the
// input callback and hand it silence while active. Linear PCM only (zeros are
// silence there); compressed input queues are left alone.
typedef struct {
    AudioQueueInputCallback callback;
    void *userData;
    BOOL pcm;
} BCQueueTap;

static void bcSilenceQueueBuffer(AudioQueueBufferRef buffer, BOOL pcm, const char *who) {
#ifdef BC_DEBUG
    static uint64_t calls;
    if (pcm && buffer->mAudioDataByteSize >= 2 && (calls++ % 50) == 0) {
        const int16_t *samples = (const int16_t *)buffer->mAudioData;
        UInt32 count = buffer->mAudioDataByteSize / 2; double sum = 0;
        for (UInt32 i = 0; i < count; i++) sum += (double)samples[i] * samples[i];
        BCLog(@"%s input level rms=%.1f active=%d", who, sqrt(sum / count), bcActive);
#ifdef BC_PROBE
        BCProbe("qrms", (uint64_t)(sqrt(sum / count) * 10));
        BCProbe("qcalls", calls);
#endif
    }
#endif
    if (bcActive && pcm && buffer->mAudioData) memset(buffer->mAudioData, 0, buffer->mAudioDataByteSize);
#ifdef BC_PROBE
    static BOOL reported;
    if (!reported) { reported = YES; BCProbe("qpcm", pcm); }
#endif
}

static void bcQueueInputTrampoline(void *userData, AudioQueueRef queue, AudioQueueBufferRef buffer, const AudioTimeStamp *time, UInt32 packets, const AudioStreamPacketDescription *descriptions) {
    BCQueueTap *tap = (BCQueueTap *)userData;
    bcSilenceQueueBuffer(buffer, tap->pcm, "AudioQueue");
    tap->callback(tap->userData, queue, buffer, time, packets, descriptions);
}

%hookf(OSStatus, AudioQueueNewInput, const AudioStreamBasicDescription *inFormat, AudioQueueInputCallback inCallbackProc, void *inUserData, CFRunLoopRef inCallbackRunLoop, CFStringRef inCallbackRunLoopMode, UInt32 inFlags, AudioQueueRef *outAQ) {
    if (!inCallbackProc || !inFormat) return %orig;
    // Lives as long as the queue; queues are few and long-lived, so it isn't freed.
    BCQueueTap *tap = (BCQueueTap *)calloc(1, sizeof(BCQueueTap));
    tap->callback = inCallbackProc;
    tap->userData = inUserData;
    tap->pcm = inFormat->mFormatID == kAudioFormatLinearPCM && !(inFormat->mFormatFlags & kAudioFormatFlagIsFloat) && inFormat->mBitsPerChannel == 16;
    BCLog(@"AudioQueueNewInput wrapped: format='%c%c%c%c' rate=%.0f ch=%u bits=%u pcm16=%d", BCFourCC(inFormat->mFormatID), inFormat->mSampleRate, (unsigned)inFormat->mChannelsPerFrame, (unsigned)inFormat->mBitsPerChannel, tap->pcm);
    return %orig(inFormat, bcQueueInputTrampoline, tap, inCallbackRunLoop, inCallbackRunLoopMode, inFlags, outAQ);
}

%hookf(OSStatus, AudioQueueNewInputWithDispatchQueue, AudioQueueRef *outAQ, const AudioStreamBasicDescription *inFormat, UInt32 inFlags, dispatch_queue_t inCallbackDispatchQueue, AudioQueueInputCallbackBlock inCallbackBlock) {
    if (!inCallbackBlock || !inFormat) return %orig;
    BOOL pcm = inFormat->mFormatID == kAudioFormatLinearPCM && !(inFormat->mFormatFlags & kAudioFormatFlagIsFloat) && inFormat->mBitsPerChannel == 16;
    AudioQueueInputCallbackBlock original = [[inCallbackBlock copy] autorelease];
    AudioQueueInputCallbackBlock wrapped = ^(AudioQueueRef queue, AudioQueueBufferRef buffer, const AudioTimeStamp *time, UInt32 packets, const AudioStreamPacketDescription *descriptions) {
        bcSilenceQueueBuffer(buffer, pcm, "AudioQueue(block)");
        original(queue, buffer, time, packets, descriptions);
    };
    BCLog(@"AudioQueueNewInputWithDispatchQueue wrapped: format='%c%c%c%c' pcm16=%d", BCFourCC(inFormat->mFormatID), pcm);
    return %orig(outAQ, inFormat, inFlags, inCallbackDispatchQueue, [[wrapped copy] autorelease]);
}

@interface CLLocationManager(BegoneCIA)
@property (nonatomic, retain) id bcDelegate;

-(void)bcUpdate;

@end


@interface AVCaptureSession(BegoneCIA)
@property (nonatomic, retain) NSMutableArray *bcInputs;

-(void)bcUpdate;

@end

%hook CLLocationManager

%property (nonatomic, retain) id bcDelegate;

// iOS 14+: every init…delegate:onQueue: variant (MapKit's MKCoreLocationProvider
// uses these) funnels into this designated initializer and never calls
// -setDelegate:, so the delegate has to be withheld here too.
-(id)initWithEffectiveBundleIdentifier:(id)bundleIdentifier bundlePath:(id)bundlePath websiteIdentifier:(id)websiteIdentifier delegate:(id)delegate silo:(id)silo {
    BCLog(@"CLLocationManager designated init, delegate: %@ (bcActive=%d)", delegate ? NSStringFromClass([delegate class]) : @"nil", bcActive);
    self = %orig(bundleIdentifier, bundlePath, websiteIdentifier, bcActive ? nil : delegate, silo);
    if (self) {
        if (delegate) self.bcDelegate = delegate;
        bcTrack(bcLocationManagers, self);
    }
    return self;
}

-(id)delegate {
    if (bcActive) {
        return NULL;
    } else {
        return %orig;
    }
}

-(void)setDelegate:(id)arg1 {
    // If we remove the delegate then that given app won't receive location updates.
    BCLog(@"CLLocationManager setDelegate: %@ (bcActive=%d)", arg1 ? NSStringFromClass([arg1 class]) : @"nil", bcActive);

    if (arg1) self.bcDelegate = arg1;

    bcTrack(bcLocationManagers, self);

    if (bcActive) {
        arg1 = NULL;
    }

    %orig;
}

-(CLLocation *)location {
    if (bcActive) {
        return NULL;
    } else {
        return %orig;
    }
}

%new
-(void)bcUpdate {
    if (!bcActive) {
        self.delegate = self.bcDelegate;
    } else {
        self.delegate = NULL;
    }
}

%end

// This kills the camera app :c
/*%hookf(CVImageBufferRef, CMSampleBufferGetImageBuffer, CMSampleBufferRef sbuf) {
    return NULL;
}*/

%hook AVCaptureSession

%property (nonatomic, retain) NSMutableArray *bcInputs;

-(void)addInput:(id)arg1 {
    BCLog(@"AVCaptureSession addInput: %@ (bcActive=%d)", arg1, bcActive);

    if (!self.bcInputs) {
        self.bcInputs = [[[NSMutableArray alloc] initWithCapacity:4] autorelease];
    }

    bcTrack(bcCaptureSessions, self);

    if (![self.bcInputs containsObject:arg1]) [self.bcInputs addObject:arg1];

    if (!bcActive) {
        %orig;
    }
}

-(void)removeInput:(id)arg1 {
    if (!bcActive) [self.bcInputs removeObject:arg1];

    %orig;
}

%new
-(void)bcUpdate {
    if (!self.bcInputs) return;
    NSArray *inputs = [[self.bcInputs copy] autorelease];
    if (!bcActive) {
        for (id obj in inputs) {
            if (obj) [self addInput:obj];
        }
    } else {
        for (id obj in inputs) {
            if (obj) [self removeInput:obj];
        }
    }
}

%end

#ifdef BC_DEBUG
// Logging-only probes to find the iOS 16 microphone path. Every hook here
// just logs the first sighting and calls through unchanged.
%group BCMicProbe

%hookf(OSStatus, AudioUnitProcessMultiple, AudioUnit unit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames, UInt32 inNumberInputBufferLists, const AudioBufferList **inInputBufferLists, UInt32 inNumberOutputBufferLists, AudioBufferList **ioOutputBufferLists) {
    AudioComponentDescription d = {0};
    AudioComponentGetDescription(AudioComponentInstanceGetComponent(unit), &d);
    if (bcFirstSighting('AUPM', d.componentType, d.componentSubType))
        BCLog(@"AudioUnitProcessMultiple: type='%c%c%c%c' subtype='%c%c%c%c'", BCFourCC(d.componentType), BCFourCC(d.componentSubType));
    return %orig;
}

%hook AVAudioRecorder
-(BOOL)record {
    BCLog(@"AVAudioRecorder record, format=%@", self.format);
    return %orig;
}
%end

%hook AVAudioEngine
-(BOOL)startAndReturnError:(NSError **)outError {
    BCLog(@"AVAudioEngine start, inputFormat=%@", [self.inputNode inputFormatForBus:0]);
    return %orig;
}
%end

%hook AVAudioInputNode
-(void)installTapOnBus:(AVAudioNodeBus)bus bufferSize:(AVAudioFrameCount)bufferSize format:(AVAudioFormat *)format block:(AVAudioNodeTapBlock)tapBlock {
    BCLog(@"AVAudioInputNode installTapOnBus:%u", (unsigned)bus);
#ifdef BC_PROBE
    // What the app actually receives: peak sample of each tapped buffer.
    AVAudioNodeTapBlock original = [tapBlock copy];
    tapBlock = ^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        static uint64_t calls; float peak = 0;
        if (buffer.floatChannelData) for (AVAudioFrameCount i = 0; i < buffer.frameLength; i++) peak = MAX(peak, fabsf(buffer.floatChannelData[0][i]));
        if ((calls++ % 20) == 0) { BCProbe("tappeak", (uint64_t)(peak * 1e6)); BCProbe("tapcalls", calls); }
        original(buffer, when);
    };
#endif
    %orig(bus, bufferSize, format, tapBlock);
}
%end

%end
#endif

static void HBCBPreferencesChanged() {
    bcActive = BCGetLiveState();
#ifdef BC_DEBUG
    if (bcIsDebugTarget()) BCLog(@"state changed: live=%d", bcActive);
#endif

    for (CLLocationManager *manager in bcTracked(bcLocationManagers)) {
        [manager bcUpdate];
    }

    for (AVCaptureSession *session in bcTracked(bcCaptureSessions)) {
        [session bcUpdate];
    }
}

%ctor {
    bcCaptureSessions = [[NSHashTable weakObjectsHashTable] retain];
    bcLocationManagers = [[NSHashTable weakObjectsHashTable] retain];

    // SpringBoard is unsandboxed and long-lived: it seeds the live notify state
    // from the persisted Cephei plist (e.g. after a reboot) and holds the name open.
    if (!strcmp(getprogname(), "SpringBoard")) {
        BOOL persisted = BCGetState();
        BCLog(@"SpringBoard seeding live state from prefs: %d", persisted);
        BCPublishState(persisted);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)BCNotification, nil, nil, true);
    }

    HBCBPreferencesChanged();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)HBCBPreferencesChanged, (CFStringRef)BCNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);

    NSLog(@"[BegoneCIA] Loaded.");
    %init;
#ifdef BC_PROBE
    BCProbe("loaded", getpid());
    BCProbe("active", bcActive);
#endif
#ifdef BC_DEBUG
    if (bcIsDebugTarget()) {
        BCLog(@"loaded, bcActive=%d", bcActive);
        %init(BCMicProbe);
    }
#endif
}
