LOCAL_PATH := $(call my-dir)

SAMSUNG_CAMERA_APK_REL := $(firstword $(wildcard \
    prebuilt/SamsungCamera.apk \
    prebuilt/SecCamera.apk \
    prebuilt/com.sec.android.app.camera.apk))

ifneq ($(strip $(SAMSUNG_CAMERA_APK_REL)),)
include $(CLEAR_VARS)
LOCAL_MODULE := SamsungStockCamera
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_SRC_FILES := $(SAMSUNG_CAMERA_APK_REL)
LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT)/priv-app/SamsungStockCamera
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_PRIVILEGED_MODULE := true
LOCAL_DEX_PREOPT := false
include $(BUILD_PREBUILT)
endif
