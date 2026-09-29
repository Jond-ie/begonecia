ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BegoneCIAModule
BegoneCIAModule_BUNDLE_EXTENSION = bundle
BegoneCIAModule_CFLAGS = -fobjc-arc
BegoneCIAModule_FILES = $(wildcard *.m)
BegoneCIAModule_LDFLAGS = $(THEOS_PROJECT_DIR)/Frameworks/ControlCenterUIKit.tbd
BegoneCIAModule_INSTALL_PATH = /Library/ControlCenter/Bundles
BegoneCIAModule_EXTRA_FRAMEWORKS = Cephei
BegoneCIAModule_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/bundle.mk
