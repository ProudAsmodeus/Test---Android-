#
# Stock Samsung camera integration for SM-A536B/DS.
# Includes prebuilt app only when a compatible APK is provided in:
#   vendor/samsung/a536b_ds/camera/prebuilt/
#

SAMSUNG_CAMERA_PREBUILT_DIR := vendor/samsung/a536b_ds/camera/prebuilt

ifneq ($(strip $(wildcard \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/SamsungCamera.apk \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/SecCamera.apk \
    $(SAMSUNG_CAMERA_PREBUILT_DIR)/com.sec.android.app.camera.apk)),)
PRODUCT_PACKAGES += SamsungStockCamera
endif
