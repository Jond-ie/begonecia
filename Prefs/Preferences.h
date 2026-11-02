#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSHeaderFooterView.h>
#import <CepheiPrefs/CepheiPrefs.h>
#import <Cephei/HBPreferences.h>
#import <spawn.h>

@interface BCPrefsListController : HBRootListController
    - (void)resetPrefs:(id)sender;
    - (void)respring:(id)sender;
@end


// Cephei 2 dropped HBImageTableCell (the original header); this draws the same full-width image.
@interface BCImageHeaderView : UIView <PSHeaderFooterView>
@end
