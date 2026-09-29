#import <notify.h>

// The persisted state lives in the Cephei plist, which on rootless is under
// /var/jb and unreadable from sandboxed processes (apps, mediaserverd reads 0).
// So the live state is mirrored into a Darwin notify state, which every
// process can read. The token is kept open for the life of the process:
// notifyd drops a name's state once nobody holds a registration on it.
static int BCStateToken(void) {
    static int token = NOTIFY_TOKEN_INVALID;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        notify_register_check(BCStateNotifyName, &token);
    });
    return token;
}

void BCPublishState(BOOL state) {
    int token = BCStateToken();
    if (token != NOTIFY_TOKEN_INVALID) notify_set_state(token, state ? 1 : 0);
}

BOOL BCGetLiveState(void) {
    uint64_t state = 0;
    int token = BCStateToken();
    if (token != NOTIFY_TOKEN_INVALID) notify_get_state(token, &state);
    return state != 0;
}

void BCSetState(BOOL state) {
    HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:BCPreferencesIdentifier];
    [preferences setBool:state forKey:BCEnabled];
    BCPublishState(state);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)BCNotification, nil, nil, true);
}

// Persisted state — only valid in unsandboxed processes (SpringBoard, CLI).
bool BCGetState() {
    HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:BCPreferencesIdentifier];
	return [([preferences objectForKey:BCEnabled] ?: @(false)) boolValue];
}
