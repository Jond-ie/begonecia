#define BCPreferencesIdentifier @"me.nepeta.begonecia"
#define BCNotification @"me.nepeta.begonecia/ReloadPrefs"
#define BCEnabled @"Enabled"
#define BCStateNotifyName "me.nepeta.begonecia/State"
// Per-app control: AppMode 0 = everywhere, 1 = off in the selected apps, 2 = only in the selected apps.
#define BCAppMode @"AppMode"
#define BCApps @"Apps"
// Posted by SpringBoard when the effective (live) state changes, e.g. on an app switch.
#define BCLiveNotification @"me.nepeta.begonecia/Live"

#import <Cephei/HBPreferences.h>
#import "BCCommon.m"