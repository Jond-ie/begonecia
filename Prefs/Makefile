include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BegoneCIAPrefs
BegoneCIAPrefs_FILES = Preferences.m
BegoneCIAPrefs_INSTALL_PATH = /Library/PreferenceBundles
BegoneCIAPrefs_FRAMEWORKS = UIKit
BegoneCIAPrefs_PRIVATE_FRAMEWORKS = Preferences
# AltList is vendored only to compile/link against; the device gets it from com.opa334.altlist.
BegoneCIAPrefs_EXTRA_FRAMEWORKS = AltList Cephei CepheiPrefs
BegoneCIAPrefs_CFLAGS = -fobjc-arc -F$(THEOS_PROJECT_DIR)/vendor -F$(THEOS_VENDOR_LIBRARY_PATH)
BegoneCIAPrefs_LDFLAGS = -F$(THEOS_PROJECT_DIR)/vendor

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/BegoneCIA.plist"$(ECHO_END)
