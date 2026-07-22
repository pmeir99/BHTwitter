ARCHS = arm64
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPEX_NAME = OpenInX

OpenInX_FILES = SafariWebExtensionHandler.m
OpenInX_FRAMEWORKS = Foundation SafariServices
OpenInX_CFLAGS = -fobjc-arc
OpenInX_INSTALL_PATH = /Applications/Twitter.app/PlugIns

include $(THEOS_MAKE_PATH)/appex.mk
