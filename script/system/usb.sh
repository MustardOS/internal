#!/bin/sh

# Thanks acmeplus!
# ADB integration based on https://github.com/knulli-cfw/distribution/blob/knulli-main/board/batocera/allwinner/h700/fsoverlay/etc/init.d/S50adb
# MTP integration based on https://github.com/viveris/uMTP-Responder/blob/master/conf/umtprd-ffs.sh

. /opt/muos/script/var/func.sh

GADGET=/sys/kernel/config/usb_gadget/muos
GADGET_CONFIG="$GADGET/configs/c.1"
GADGET_FUNCTIONS="$GADGET/functions"
GADGET_STRINGS="$GADGET/strings/0x409"

# Path /dev/usb-ffs/adb is hardcoded inside adbd. :/
FUNCTIONFS=/dev/usb-ffs

UDC="$(GET_VAR "device" "board/udc")"
USB_FUNCTION="$(GET_VAR "global" "settings/advanced/usb_function")"

USB_VID() {
	echo 0x1d6b # Linux Foundation (https://usb-ids.gowdy.us/read/UD/1d6b)
}

USB_PID() {
	case "$USB_FUNCTION" in
		mtp) echo 0x0100 ;; # PTP Gadget
		*) echo 0x0105 ;;   # FunctionFS Gadget
	esac
}

USB_SERIAL() {
	/opt/muos/script/system/serial.sh
}

USB_MANUFACTURER() {
	echo muOS
}

USB_PRODUCT() {
	cat /opt/muos/config/device.txt
}

FIRMWARE_VERSION() {
	head -n 1 /opt/muos/config/version.txt
}

START() {
	# Configure USB gadget
	# (https://docs.kernel.org/usb/gadget_configfs.html).
	mkdir "$GADGET" "$GADGET_STRINGS" "$GADGET_CONFIG"

	USB_VID >"$GADGET/idVendor"
	USB_PID >"$GADGET/idProduct"

	USB_SERIAL >"$GADGET_STRINGS/serialnumber"
	USB_MANUFACTURER >"$GADGET_STRINGS/manufacturer"
	USB_PRODUCT >"$GADGET_STRINGS/product"

	# The device can charge while a USB gadget is enabled. Charging may draw
	# more power, but 500 mA is the most a USB 2.0 device can claim to need.
	echo 500 >"$GADGET_CONFIG/MaxPower"

	# Configure USB function (https://docs.kernel.org/usb/functionfs.html).
	mkdir "$GADGET_FUNCTIONS/ffs.$USB_FUNCTION"
	ln -s "$GADGET_FUNCTIONS/ffs.$USB_FUNCTION" "$GADGET_CONFIG"

	mkdir -p "$FUNCTIONFS/$USB_FUNCTION"
	mount -t functionfs "$USB_FUNCTION" "$FUNCTIONFS/$USB_FUNCTION"

	# Start daemon.
	case "$USB_FUNCTION" in
		adb) /usr/bin/adbd & ;;
		mtp) UPDATE_UMTPRD_CONF && /usr/bin/umtprd & ;;
	esac
	sleep 1

	# Enable USB gadget.
	echo "$UDC" >"$GADGET/UDC"
}

UPDATE_UMTPRD_CONF() {
	# Hide SD2 folder if unmounted. Checking here doesn't handle the user
	# (un)plugging SD2 with the device running, but that's likely uncommon.
	if [ "$(GET_VAR "device" "storage/sdcard/active")" -eq 1 ]; then
		sed 's|^#storage "/mnt/sdcard"|storage "/mnt/sdcard"|' -i /etc/umtprd/umtprd.conf
	else
		sed 's|^storage "/mnt/sdcard"|#storage "/mnt/sdcard"|' -i /etc/umtprd/umtprd.conf
	fi

	sed \
		-e "s/^usb_vendor_id .*/usb_vendor_id \"$(USB_VID)\"/" \
		-e "s/^usb_product_id .*/usb_product_id \"$(USB_PID)\"/" \
		-e "s/^serial .*/serial \"$(USB_SERIAL)\"/" \
		-e "s/^manufacturer .*/manufacturer \"$(USB_MANUFACTURER)\"/" \
		-e "s/^product .*/product \"$(USB_PRODUCT)\"/" \
		-e "s/^firmware_version .*/firmware_version \"$(FIRMWARE_VERSION)\"/" \
		-i /etc/umtprd/umtprd.conf
}

STOP() {
	# Disable USB gadget.
	echo '' >"$GADGET/UDC"

	# Stop daemon.
	killall -q adbd umtprd
	sleep 1

	# Clean up USB function.
	for FUNCTION in adb mtp; do
		[ -d "$FUNCTIONFS/$FUNCTION" ] && umount -q "$FUNCTIONFS/$FUNCTION"
		[ -L "$GADGET_CONFIG/ffs.$FUNCTION" ] && rm "$GADGET_CONFIG/ffs.$FUNCTION"
		[ -d "$GADGET_FUNCTIONS/ffs.$FUNCTION" ] && rmdir "$GADGET_FUNCTIONS/ffs.$FUNCTION"
	done
	rm -rf "$FUNCTIONFS"

	# Clean up USB gadget. Note that configfs items must be removed with
	# rmdir, not rm, even though the relevant directories appear nonempty.
	# (See also https://docs.kernel.org/filesystems/configfs.html and
	# https://docs.kernel.org/usb/gadget_configfs.html#cleaning-up.)
	rmdir "$GADGET_CONFIG" "$GADGET_STRINGS" "$GADGET"
}

[ -n "$UDC" ] || exit # USB function requires a USB Device Controller (UDC).

case "$USB_FUNCTION" in
	adb | mtp)
		# Check if specified function is running; start it if not.
		if [ ! -d "$GADGET_FUNCTIONS/ffs.$USB_FUNCTION" ]; then
			[ -d "$GADGET" ] && STOP
			START
		fi
		;;
	none) [ -d "$GADGET" ] && STOP ;;
	*)
		printf "Invalid usb_function setting: %s\n" "$USB_FUNCTION" >&2
		exit 1
		;;
esac
