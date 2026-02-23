LOCAL_PATH := $(call my-dir)

MOTO_CAMERA_APK_REL := $(firstword $(wildcard \
    prebuilt/MotoCamera.apk \
    prebuilt/MotorolaCamera.apk \
    prebuilt/com.motorola.camera3.apk))

ifneq ($(strip $(MOTO_CAMERA_APK_REL)),)
include $(CLEAR_VARS)
LOCAL_MODULE := MotoStockCamera
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_SRC_FILES := $(MOTO_CAMERA_APK_REL)
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT)/priv-app/MotoStockCamera
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_PRIVILEGED_MODULE := true
LOCAL_DEX_PREOPT := false
include $(BUILD_PREBUILT)
endif
