TARGET := iphone:clang:latest:6.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = empty ReExtendioDylib

empty_FILES = empt.c
empty_INSTALL_PATH = /usr/local/lib

ReExtendioDylib_FILES = ReExtendioDylib.c
ReExtendioDylib_LDFLAGS = -Xlinker -reexport_library $(THEOS_OBJ_DIR)/empty.dylib -current_version 1.0.0 -compatibility_version 1.0.0
ReExtendioDylib_INSTALL_PATH = /usr/local/lib

include $(THEOS_MAKE_PATH)/library.mk
