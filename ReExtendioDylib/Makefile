TARGET := iphone:clang:latest:6.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = empty emptyfoundation ReExtendioDylib

empty_FILES = empt.c
empty_INSTALL_PATH = /usr/local/lib

emptyfoundation_FILES = empt.c
emptyfoundation_INSTALL_PATH = /usr/local/lib

ReExtendioDylib_FILES = ReExtendioDylib.m
ReExtendioDylib_CFLAGS = -fobjc-arc -Wno-objc-property-implementation -Wno-protocol -Wno-objc-designated-initializers -Wno-nonnull -Wno-atomic-property-with-user-defined-accessor -Wno-incomplete-implementation
ReExtendioDylib_LDFLAGS = -Xlinker -reexport_library $(THEOS_OBJ_DIR)/empty.dylib -Xlinker -reexport_library $(THEOS_OBJ_DIR)/emptyfoundation.dylib -current_version 1.0.0 -compatibility_version 1.0.0
ReExtendioDylib_INSTALL_PATH = /usr/local/lib

include $(THEOS_MAKE_PATH)/library.mk
