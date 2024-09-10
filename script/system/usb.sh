#!/bin/sh

# Thanks acmeplus!
# ADB integration based on https://github.com/knulli-cfw/distribution/blob/knulli-main/board/batocera/allwinner/h700/fsoverlay/etc/init.d/S50adb
# MTP integration based on https://github.com/viveris/uMTP-Responder/blob/master/conf/umtprd-ffs.sh

. /opt/muos/script/var/func.sh

GADGET=/sys/kernel/config/usb_gadget/muos
GADGET_CONFIG="$GADGET/configs/c.1"
GADGET_CONFIG_STRINGS="$GADGET_CONFIG/strings/0x409"
GADGET_FUNCTIONS="$GADGET/functions"
GADGET_STRINGS="$GADGET/strings/0x409"

# Path /dev/usb-ffs/adb is hardcoded inside adbd. :/
FUNCTIONFS=/dev/usb-ffs

USB_FUNCTION="$(GET_VAR "global" "settings/advanced/usb_function")"

# See https://usb-ids.gowdy.us/read/UD/1d6b for USB vendor and product IDs.

USB_VID() {
	echo 0x1d6b # Linux Foundation
}

USB_PID() {
	case "$USB_FUNCTION" in
		mtp) echo 0x0100 ;; # PTP Gadget
		*) echo 0x0105 ;; # FunctionFS Gadget
	esac
}

USB_SERIAL() {
	# Randomized on setup. If the user changes it, they're on their own. :)
	hostname -s
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
	if ! mountpoint -q /sys/kernel/config; then
		mount -t configfs none /sys/kernel/config
	fi

	mkdir "$GADGET"
	USB_VID >"$GADGET/idVendor"
	USB_PID >"$GADGET/idProduct"

	mkdir "$GADGET_STRINGS"
	USB_SERIAL >"$GADGET_STRINGS/serialnumber"
	USB_MANUFACTURER >"$GADGET_STRINGS/manufacturer"
	USB_PRODUCT >"$GADGET_STRINGS/product"

	mkdir "$GADGET_CONFIG"

	mkdir "$GADGET_CONFIG_STRINGS"
	echo "Configuration 1" >"$GADGET_CONFIG_STRINGS/configuration"

	# Configure USB functions (https://docs.kernel.org/usb/functionfs.html).
	mkdir "$GADGET_FUNCTIONS/ffs.$USB_FUNCTION"
	ln -s "$GADGET_FUNCTIONS/ffs.$USB_FUNCTION" "$GADGET_CONFIG"

	mkdir -p "$FUNCTIONFS/$USB_FUNCTION"
	mount -t functionfs "$USB_FUNCTION" "$FUNCTIONFS/$USB_FUNCTION"

	# Start daemon.
	case "$USB_FUNCTION" in
		adb)
			/usr/bin/adbd &
			;;
		mtp)
			UPDATE_UMTPRD_CONFIG
			/usr/bin/umtprd &
			;;
	esac
	sleep 1

	# Enable USB gadget.
	echo 5100000.udc-controller >"$GADGET/UDC"
}

UPDATE_UMTPRD_CONFIG() {
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
	# Check if USB gadget is already stopped.
	[ -d "$GADGET" ] || return

	# Disable USB gadget.
	echo '' >"$GADGET/UDC"

	# Stop daemons.
	killall -q adbd umtprd
	sleep 1

	# Clean up USB functions.
	for FUNCTION in adb mtp; do
		[ -d "$FUNCTIONFS/$FUNCTION" ] && umount -q "$FUNCTIONFS/$FUNCTION"
		[ -L "$GADGET_CONFIG/ffs.$FUNCTION" ] && rm "$GADGET_CONFIG/ffs.$FUNCTION"
		[ -d "$GADGET_FUNCTIONS/ffs.$FUNCTION" ] && rmdir "$GADGET_FUNCTIONS/ffs.$FUNCTION"
	done
	rm -rf "$FUNCTIONFS"

	# Clean up USB gadget. Note that `rm -rf` inside configfs fails with
	# "Operation not permitted" errors. Instead, `rmdir` commands must be
	# used in a specific order, even though the directories appear nonempty
	# (https://docs.kernel.org/usb/gadget_configfs.html#cleaning-up).
	rmdir "$GADGET_CONFIG_STRINGS"
	rmdir "$GADGET_CONFIG"
	rmdir "$GADGET_STRINGS"
	rmdir "$GADGET"
}

case "$USB_FUNCTION" in
	adb|mtp)
		# Check if specified gadget is already running; start it if not.
		if [ ! -d "$GADGET_FUNCTIONS/ffs.$USB_FUNCTION" ]; then
			STOP
			START
		fi
		;;
	host) STOP ;;
	*)
		printf "Invalid USB function setting: %s\n" "$USB_FUNCTION" >&2
		exit 1
		;;
esac
