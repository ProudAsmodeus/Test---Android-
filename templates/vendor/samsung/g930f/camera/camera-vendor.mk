#
# Stock Samsung camera integration for SM-G930F.
# Includes prebuilt app only when a compatible APK is provided in:
#   vendor/samsung/g930f/camera/prebuilt/
#

SAMSUNG_CAMERA_PREBUILT_DIR := vendor/samsung/g930f/camera/prebuilt

ifneq ($(strip $(wildcard \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/SamsungCamera7.apk \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/SamsungCamera6.apk \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/SamsungCamera.apk \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/SecCamera.apk \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/com.sec.android.app.camera.apk)),)
PRODUCT_PACKAGES += SamsungStockCamera
endif
