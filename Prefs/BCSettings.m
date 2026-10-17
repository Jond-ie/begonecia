// BegoneCIA settings: the master switch and per-app control.
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <AltList/ATLApplicationListMultiSelectionController.h>
#import <Preferences/PSListItemsController.h>
#import <notify.h>
#import <objc/message.h>

#define BCDomain CFSTR("me.nepeta.begonecia")

static id BCRead(NSString *key) {
    CFPreferencesAppSynchronize(BCDomain);
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, BCDomain));
}

// Writes a setting and tells SpringBoard, which re-decides the live state.
static void BCWrite(NSString *key, id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, BCDomain);
    CFPreferencesAppSynchronize(BCDomain);
    notify_post("me.nepeta.begonecia/ReloadPrefs");
}

@interface BCRootListController : PSListController
@end

@implementation BCRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        PSSpecifier *main = [PSSpecifier groupSpecifierWithName:nil];
        [main setProperty:@"Blocks the microphone, camera and location for every app. Same as the Control Center toggle." forKey:@"footerText"];
        [specs addObject:main];
        PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"Block Mic, Camera & Location" target:self
            set:@selector(setEnabled:specifier:) get:@selector(enabled:) detail:nil cell:PSSwitchCell edit:nil];
        [specs addObject:enabled];

        PSSpecifier *perApp = [PSSpecifier groupSpecifierWithName:@"Per App"];
        [perApp setProperty:@"Off in Selected Apps: blocking pauses while one of them is open and comes back when you leave it. Only in Selected Apps: blocking only runs while one of them is open. Apps running in the background follow the app on screen." forKey:@"footerText"];
        [specs addObject:perApp];
        PSSpecifier *mode = [PSSpecifier preferenceSpecifierNamed:@"Mode" target:self set:@selector(setMode:specifier:) get:@selector(mode:)
            detail:PSListItemsController.class cell:PSLinkListCell edit:nil];
        // -setValues:titles: is in Preferences but not in Theos' headers.
        ((void (*)(id, SEL, id, id))objc_msgSend)(mode, NSSelectorFromString(@"setValues:titles:"), @[@0, @1, @2], @[@"Everywhere", @"Off in Selected Apps", @"Only in Selected Apps"]);
        [specs addObject:mode];
        PSSpecifier *apps = [PSSpecifier preferenceSpecifierNamed:@"Selected Apps" target:self set:@selector(setApps:specifier:) get:@selector(apps:)
            detail:ATLApplicationListMultiSelectionController.class cell:PSLinkCell edit:nil];
        [apps setProperty:@YES forKey:@"useSearchBar"];
        [apps setProperty:@[@{ @"sectionType": @"Visible" }] forKey:@"sections"];
        [specs addObject:apps];

        PSSpecifier *triggr = [PSSpecifier groupSpecifierWithName:nil];
        [triggr setProperty:@"With Triggr 2 installed, Turn BegoneCIA On, Off and Toggle are in Triggr's actions (BegoneCIA category)." forKey:@"footerText"];
        [specs addObject:triggr];
        _specifiers = specs;
    }
    return _specifiers;
}

- (id)enabled:(PSSpecifier *)spec { return BCRead(@"Enabled") ?: @NO; }
- (void)setEnabled:(id)value specifier:(PSSpecifier *)spec { BCWrite(@"Enabled", value); }
- (id)mode:(PSSpecifier *)spec { return BCRead(@"AppMode") ?: @0; }
- (void)setMode:(id)value specifier:(PSSpecifier *)spec { BCWrite(@"AppMode", value); }
- (id)apps:(PSSpecifier *)spec { id a = BCRead(@"Apps"); return [a isKindOfClass:NSArray.class] ? a : @[]; }
- (void)setApps:(id)value specifier:(PSSpecifier *)spec { BCWrite(@"Apps", value); }

@end
