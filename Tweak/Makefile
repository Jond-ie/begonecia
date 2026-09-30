ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BegoneCIA
BegoneCIA_FILES = Tweak.xm
# NOTE: no -fobjc-arc here — the upstream tweak is written for MRC
# (manual retain, %property retain). Adding ARC would change its semantics.
BegoneCIA_EXTRA_FRAMEWORKS = Cephei
# Explicit C++ standard for Tweak.xm (Objective-C++): newer Cephei headers use C++11
# syntax, and Xcode clang defaults to C++98.
BegoneCIA_CCFLAGS = -std=c++17
# Debug logging (view with `oslog` on device): make ... BC_DEBUG=1
ifeq ($(BC_DEBUG),1)
BegoneCIA_CFLAGS = -DBC_DEBUG
endif
BegoneCIA_FRAMEWORKS = AVFoundation CoreLocation CoreMedia CoreVideo AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk
