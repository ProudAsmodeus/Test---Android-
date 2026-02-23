#
# Stock Motorola camera integration for XT2601-2.
# Includes prebuilt app only when a compatible APK is provided in:
#   vendor/motorola/edge70_xt2601_2/camera/prebuilt/
#

MOTO_CAMERA_PREBUILT_DIR := vendor/motorola/edge70_xt2601_2/camera/prebuilt

ifneq ($(strip $(wildcard \
    $(MOTO_CAMERA_PREBUILT_DIR)/MotoCamera.apk \
    $(MOTO_CAMERA_PREBUILT_DIR)/MotorolaCamera.apk \
    $(MOTO_CAMERA_PREBUILT_DIR)/com.motorola.camera3.apk)),)
PRODUCT_PACKAGES += MotoStockCamera
endif
