// Nepeta's original BegoneCIA settings page, ported as-is (Cephei 2, rootless/RootHide paths, ARC),
// with the original's Disable in calls + Disable BegoneCIA for applications options.
#import "Preferences.h"
#import <AltList/ATLApplicationListMultiSelectionController.h>
#import <notify.h>
#import <rootless.h>

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

@implementation BCImageHeaderView {
    UIImageView *_imageView;
}

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        NSString *name = [specifier propertyForKey:@"icon"];
        UIImage *image = name ? [UIImage imageNamed:name inBundle:[NSBundle bundleForClass:self.class] compatibleWithTraitCollection:nil] : nil;
        _imageView = [[UIImageView alloc] initWithImage:image];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.frame = self.bounds;
        [self addSubview:_imageView];
    }
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    CGSize size = _imageView.image.size;
    return size.width > 0 ? width * size.height / size.width : 0;
}
@end

@implementation BCPrefsListController
- (instancetype)init {
    self = [super init];

    if (self) {
        HBAppearanceSettings *appearanceSettings = [[HBAppearanceSettings alloc] init];
        // The original's near-black tint, kept in light mode; white in dark mode so the buttons stay readable.
        appearanceSettings.tintColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.9 alpha:1] : [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1];
        }];
        appearanceSettings.tableViewCellSeparatorColor = [UIColor colorWithWhite:0 alpha:0];
        appearanceSettings.largeTitleStyle = HBAppearanceSettingsLargeTitleStyleNever; // the original predates large titles
        self.hb_appearanceSettings = appearanceSettings;
    }

    return self;
}

// The original's "Disable BegoneCIA for applications" row (it used AppList; AltList is the modern equivalent).
- (PSSpecifier *)appsSpecifier {
    PSSpecifier *apps = [PSSpecifier preferenceSpecifierNamed:@"Disable BegoneCIA for applications" target:self set:@selector(setApps:specifier:) get:@selector(apps:)
        detail:ATLApplicationListMultiSelectionController.class cell:PSLinkCell edit:nil];
    [apps setProperty:@YES forKey:@"useSearchBar"];
    [apps setProperty:@[@{ @"sectionType": @"Visible" }] forKey:@"sections"];
    return apps;
}

- (id)specifiers {
    if(_specifiers == nil) {
        NSMutableArray *specs = [[self loadSpecifiersFromPlistName:@"Prefs" target:self] mutableCopy];
        NSUInteger calls = [specs indexOfObjectPassingTest:^BOOL(PSSpecifier *s, NSUInteger i, BOOL *stop) { return [s.properties[@"key"] isEqual:@"DisableInCalls"]; }];
        if (calls != NSNotFound) [specs insertObject:[self appsSpecifier] atIndex:calls + 1];
        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    self.table.tintColor = self.hb_appearanceSettings.tintColor; // Cephei 2 no longer tints button rows

    [self.navigationController.navigationController.navigationBar setShadowImage: [UIImage new]];
    self.navigationController.navigationController.navigationBar.translucent = YES;
}

- (id)apps:(PSSpecifier *)spec { id a = BCRead(@"Apps"); return [a isKindOfClass:NSArray.class] ? a : @[]; }
- (void)setApps:(id)value specifier:(PSSpecifier *)spec {
    BCWrite(@"AppMode", @1); // the list means "off in these apps", as in the original
    BCWrite(@"Apps", value);
}

- (void)resetPrefs:(id)sender {
    HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"me.nepeta.begonecia"];
    [prefs removeAllObjects];

    [self respring:sender];
}

- (void)respring:(id)sender {
	pid_t pid;
    const char* args[] = {"killall", "backboardd", NULL};
    posix_spawn(&pid, ROOT_PATH("/usr/bin/killall"), NULL, NULL, (char* const*)args, NULL);
}
@end
