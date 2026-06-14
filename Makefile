TARGET := iphone:clang:latest:6.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = GameController Photos

GameController_FILES = GameController.x
GameController_CFLAGS = -fobjc-arc
GameController_LDFLAGS = -current_version 1.0.0 -compatibility_version 1.0.0
GameController_INSTALL_PATH = /usr/local/lib

Photos_FILES = Photos.x
Photos_CFLAGS = -fobjc-arc
Photos_LDFLAGS = -current_version 1.0.0 -compatibility_version 1.0.0
Photos_INSTALL_PATH = /usr/local/lib

include $(THEOS_MAKE_PATH)/library.mk
