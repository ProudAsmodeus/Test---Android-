#
# ROM version metadata (updated by bootstrap script).
#

ROM_NAME := BaseROM
ROM_VERSION := 0.1.0

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.rom.name=$(ROM_NAME) \
    ro.rom.version=$(ROM_VERSION)
