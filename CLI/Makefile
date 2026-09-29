ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = begonecia
begonecia_FILES = main.m
begonecia_CFLAGS = -fobjc-arc
begonecia_EXTRA_FRAMEWORKS = Cephei
begonecia_FRAMEWORKS = Foundation
begonecia_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
