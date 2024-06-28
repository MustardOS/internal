#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/firmware.sh

. /opt/muos/script/var/global/boot.sh

TRANSFER_FIRMWARE() {
	PACKAGE="$1"
	FW_OUT="$2"
	FW_SEEK="$3"

	LOGGER "$0" "FIRMWARE UPDATE" "Updating '$PACKAGE' for device!"
	dd if=/opt/muos/device/"$DEVICE_TYPE"/firmware/"$PACKAGE" of=/dev/"$FW_OUT" seek="$FW_SEEK" conv=notrunc,fsync
}

BOOT_BIN_PATH="/opt/muos/device/$DEVICE_TYPE/firmware/boot.bin"
PACK_BIN_PATH="/opt/muos/device/$DEVICE_TYPE/firmware/package.bin"

if [ "$GC_BOO_FIRMWARE_DONE" -eq 0 ]; then
	FW_DONE=0

	if [ -f "$BOOT_BIN_PATH" ]; then
		TRANSFER_FIRMWARE "boot.bin" "$DC_FIR_BOOT_OUT" "$DC_FIR_BOOT_SEEK"
		FW_DONE=1
	fi

	if [ -f "$PACK_BIN_PATH" ]; then
		TRANSFER_FIRMWARE "package.bin" "$DC_FIR_PACKAGE_OUT" "$DC_FIR_PACKAGE_SEEK"
		FW_DONE=1
	fi

	MODIFY_INI "$GLOBAL_CONFIG" "boot" "firmware_done" "1"

	if [ "$FW_DONE" -eq 1 ]; then
		reboot
	fi
fi
