#!/bin/sh

# ADB integration based on https://github.com/knulli-cfw/distribution/blob/knulli-main/board/batocera/allwinner/h700/fsoverlay/etc/init.d/S50adb
# MTP integration based on https://github.com/viveris/uMTP-Responder/blob/master/conf/umtprd-ffs.sh

. /opt/muos/script/var/func.sh

GADGET="/sys/kernel/config/usb_gadget/muos"

GCFG="$GADGET/configs/c.1"
GFUN="$GADGET/functions"
GSTR="$GADGET/strings/0x409"

FFS_ROOT="/dev/usb-ffs"
UDC="$(GET_VAR "device" "board/udc")"

LOCK_DIR="/run/muos/lock"
LOCK_PATH="$LOCK_DIR/usb_gadgetd.lock"
PID_FILE="$LOCK_PATH/pid"

GET_USB_FUNCTION() {
	GET_VAR "config" "settings/advanced/usb_function"
}

USB_PID() {
	CUR_FUNC="$(GET_USB_FUNCTION)"

	case "$CUR_FUNC" in
		mtp) echo 0x0100 ;;
		*) echo 0x0105 ;;
	esac
}

USB_VID() {
	echo 0x1d6b
}

USB_SERIAL() {
	/opt/muos/script/system/serial.sh
}

USB_MANUFACTURER() {
	echo MustardOS
}

USB_PRODUCT() {
	tr '[:lower:]' '[:upper:]' </opt/muos/device/config/board/name | awk '{$1=$1;print}'
}

FIRMWARE_VERSION() {
	head -n 1 /opt/muos/config/system/version
}

IS_MOUNTED() {
	mount | grep -q " on $1 type "
}

IS_RUNNING() {
	pidof "$1" >/dev/null 2>&1
}

ENSURE_CONFIG_FS() {
	[ -d /sys/kernel/config ] || mount -t configfs none /sys/kernel/config 2>/dev/null
}

UNBIND_UDC() {
	[ -e "$GADGET/UDC" ] || return 0

	if [ -n "$(cat "$GADGET/UDC" 2>/dev/null)" ]; then
		printf '' >"$GADGET/UDC" 2>/dev/null
		sleep 0.1
	fi
}

BIND_UDC() {
	[ -n "$UDC" ] || return 1
	[ -z "$(cat "$GADGET/UDC" 2>/dev/null)" ] && echo "$UDC" >"$GADGET/UDC"
}

CREATE_GADGET_SHELL() {
	mkdir -p "$GADGET" "$GSTR" "$GCFG"

	USB_VID >"$GADGET/idVendor"
	USB_PID >"$GADGET/idProduct"
	USB_SERIAL >"$GSTR/serialnumber"
	USB_MANUFACTURER >"$GSTR/manufacturer"
	USB_PRODUCT >"$GSTR/product"

	echo 500 >"$GCFG/MaxPower"
}

MOUNT_FFS() {
	F="$1"

	mkdir -p "$GFUN/ffs.$F"
	[ -L "$GCFG/ffs.$F" ] || ln -s "$GFUN/ffs.$F" "$GCFG/ffs.$F"

	mkdir -p "$FFS_ROOT/$F"
	if ! IS_MOUNTED "$FFS_ROOT/$F"; then
		mount -t functionfs "$F" "$FFS_ROOT/$F"
	fi
}

UMOUNT_FFS() {
	F="$1"
	if IS_MOUNTED "$FFS_ROOT/$F"; then
		umount "$FFS_ROOT/$F" 2>/dev/null || umount -l "$FFS_ROOT/$F" 2>/dev/null
	fi

	[ -L "$GCFG/ffs.$F" ] && rm -f "$GCFG/ffs.$F"
	[ -d "$GFUN/ffs.$F" ] && rmdir "$GFUN/ffs.$F" 2>/dev/null

	[ -d "$FFS_ROOT/$F" ] && rmdir "$FFS_ROOT/$F" 2>/dev/null
}

START_DAEMON_PROC() {
	case "$1" in
		adb) IS_RUNNING adbd || /usr/bin/adbd & ;;
		mtp)
			UPDATE_UMTPRD_CONF
			IS_RUNNING umtprd || /usr/bin/umtprd &
			;;
	esac
}

STOP_DAEMONS() {
	if IS_RUNNING adbd; then killall -q adbd; fi
	if IS_RUNNING umtprd; then killall -q umtprd; fi

	sleep 0.25

	IS_RUNNING adbd && killall -q -KILL adbd
	IS_RUNNING umtprd && killall -q -KILL umtprd
}

CURRENT_FUNCTION() {
	if [ -L "$GCFG/ffs.adb" ] && [ ! -L "$GCFG/ffs.mtp" ]; then
		echo adb
	elif [ -L "$GCFG/ffs.mtp" ] && [ ! -L "$GCFG/ffs.adb" ]; then
		echo mtp
	elif [ -L "$GCFG/ffs.adb" ] && [ -L "$GCFG/ffs.mtp" ]; then
		echo mixed
	else
		echo none
	fi
}

DAEMON_UP() {
	case "$1" in
		adb) pidof adbd >/dev/null 2>&1 ;;
		mtp) pidof umtprd >/dev/null 2>&1 ;;
		*) return 1 ;;
	esac
}

SWITCH_TO() {
	TGT="$1"
	OTHER="$([ "$TGT" = adb ] && echo mtp || echo adb)"

	if [ "$(CURRENT_FUNCTION)" = "$TGT" ] && IS_MOUNTED "$FFS_ROOT/$TGT" && DAEMON_UP "$TGT"; then
		BIND_UDC
		return 0
	fi

	UNBIND_UDC
	STOP_DAEMONS
	UMOUNT_FFS "$OTHER"

	MOUNT_FFS "$TGT"
	START_DAEMON_PROC "$TGT"

	sleep 0.25
	BIND_UDC
}

UPDATE_UMTPRD_CONF() {
	if [ "$(GET_VAR "device" "storage/sdcard/active")" -eq 1 ]; then
		sed -i 's|^#storage "/mnt/sdcard"|storage "/mnt/sdcard"|' /etc/umtprd/umtprd.conf
	else
		sed -i 's|^storage "/mnt/sdcard"|#storage "/mnt/sdcard"|' /etc/umtprd/umtprd.conf
	fi

	sed -i \
		-e "s/^usb_vendor_id .*/usb_vendor_id \"$(USB_VID)\"/" \
		-e "s/^usb_product_id .*/usb_product_id \"$(USB_PID)\"/" \
		-e "s/^serial .*/serial \"$(USB_SERIAL)\"/" \
		-e "s/^manufacturer .*/manufacturer \"$(USB_MANUFACTURER)\"/" \
		-e "s/^product .*/product \"$(USB_PRODUCT)\"/" \
		-e "s/^firmware_version .*/firmware_version \"$(FIRMWARE_VERSION)\"/" \
		/etc/umtprd/umtprd.conf
}

START_GADGET() {
	ENSURE_CONFIG_FS
	CREATE_GADGET_SHELL

	case "$USB_FUNCTION" in
		adb | mtp)
			MOUNT_FFS "$USB_FUNCTION"
			START_DAEMON_PROC "$USB_FUNCTION"
			sleep 0.2
			BIND_UDC
			;;
	esac
}

STOP_GADGET() {
	UNBIND_UDC
	STOP_DAEMONS

	UMOUNT_FFS adb
	UMOUNT_FFS mtp

	rmdir "$GCFG" 2>/dev/null
	rmdir "$GSTR" 2>/dev/null

	rmdir "$GADGET" 2>/dev/null
}

REPAIR_AFTER_RESUME() {
	if [ -d "$GADGET" ]; then
		case "$USB_FUNCTION" in
			adb | mtp)
				MOUNT_FFS "$USB_FUNCTION"
				START_DAEMON_PROC "$USB_FUNCTION"
				;;
		esac
		BIND_UDC
	fi
}

READ_UDC_STATE() {
	# Typical values: "not attached", "powered", "attached", "configured"
	if [ -n "$UDC" ] && [ -r "/sys/class/udc/$UDC/state" ]; then
		ST=$(tr -d "\r" <"/sys/class/udc/$UDC/state" 2>/dev/null)
		printf '%s' "$ST"
	else
		printf '%s' "unknown"
	fi
}

REBIND_UDC() {
	UNBIND_UDC
	sleep 0.15
	BIND_UDC
}

ENSURE_DESIRED_STATE() {
	CUR_FUNC="$(GET_USB_FUNCTION)"
	case "$CUR_FUNC" in
		none) [ -d "$GADGET" ] && STOP_GADGET ;;
		adb | mtp)
			USB_FUNCTION="$CUR_FUNC"
			if [ ! -d "$GADGET" ]; then
				ENSURE_CONFIGFS
				CREATE_GADGET_SHELL
				SWITCH_TO "$USB_FUNCTION"
			else
				SWITCH_TO "$USB_FUNCTION"
			fi
			;;
		*) ;;
	esac
}

ACQUIRE_LOCK() {
	mkdir -p "$LOCK_DIR"
	if mkdir "$LOCK_PATH" 2>/dev/null; then
		printf '%s\n' "$$" >"$PID_FILE"
		trap 'rm -rf "$LOCK_PATH"; exit 0' INT HUP TERM EXIT
		return 0
	fi

	if [ -r "$PID_FILE" ]; then
		OLD_PID="$(cat "$PID_FILE" 2>/dev/null)"
		if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
			return 1
		fi
	fi

	rm -rf "$LOCK_PATH" 2>/dev/null
	if mkdir "$LOCK_PATH" 2>/dev/null; then
		printf '%s\n' "$$" >"$PID_FILE"
		trap 'rm -rf "$LOCK_PATH"; exit 0' INT HUP TERM EXIT
		return 0
	fi

	return 1
}

WATCHDOG_LOOP() {
	ACQUIRE_LOCK || exit 0

	INTERVAL="1"
	STALL_REBIND_SECS="4"
	STALL_COUNT=0

	ENSURE_DESIRED_STATE

	while :; do
		[ -n "$UDC" ] || {
			sleep "$INTERVAL"
			continue
		}

		ENSURE_DESIRED_STATE
		STATE="$(READ_UDC_STATE)"

		case "$STATE" in
			configured | "configured with interfaces")
				STALL_COUNT=0
				;;
			"not attached")
				STALL_COUNT=0
				;;
			powered | attached | "configured with no interfaces")
				STALL_COUNT=$((STALL_COUNT + 1))
				if [ "$STALL_COUNT" -ge "$STALL_REBIND_SECS" ]; then
					REBIND_UDC
					STALL_COUNT=0
				fi
				;;
			*)
				BIND_UDC
				;;
		esac

		sleep "$INTERVAL"
	done
}

CMD_START() {
	if [ -r "$PID_FILE" ]; then
		P="$(cat "$PID_FILE" 2>/dev/null)"
		if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
			printf "usb_gadgetd: already running (pid %s)\n" "$P"
			return 0
		fi
	fi

	nohup "$0" __watchdog >/dev/null 2>&1 &
	sleep 0.25

	if [ -r "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
		printf "usb_gadgetd: started (pid %s)\n" "$(cat "$PID_FILE")"
		return 0
	fi

	printf "usb_gadgetd: failed to start\n" >&2
	return 1
}

CMD_STOP() {
	if [ -r "$PID_FILE" ]; then
		P="$(cat "$PID_FILE" 2>/dev/null)"
		if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
			kill "$P" 2>/dev/null
			sleep 0.2
			kill -9 "$P" 2>/dev/null
		else
			printf "usb_gadgetd: stale lock (pid %s)\n" "$P"
		fi
	fi

	rm -rf "$LOCK_PATH" 2>/dev/null
	printf "usb_gadgetd: stopped\n"
}

CMD_STATUS() {
	if [ -r "$PID_FILE" ]; then
		P="$(cat "$PID_FILE" 2>/dev/null)"
		if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
			printf "Watchdog: running (pid %s)\n" "$P"
		else
			printf "Watchdog: not running (stale pid %s)\n" "$P"
		fi
	else
		printf "Watchdog: not running\n"
	fi

	if [ -z "$UDC" ]; then
		printf "UDC: not present\n"
		return 0
	fi

	STATE="$(READ_UDC_STATE)"
	printf "UDC: %s (%s)\n" "$UDC" "$STATE"

	if [ -d "$GADGET" ]; then
		BOUND="$(cat "$GADGET/UDC" 2>/dev/null)"
		[ -n "$BOUND" ] && printf "Gadget: bound to %s\n" "$BOUND" || printf "Gadget: unbound\n"
	else
		printf "Gadget: not created\n"
	fi

	CUR_FUNC="$(GET_USB_FUNCTION)"
	printf "Config usb_function: %s\n" "$CUR_FUNC"

	for F in adb mtp; do
		if IS_MOUNTED "$FFS_ROOT/$F"; then
			printf "FunctionFS %-3s: mounted\n" "$F"
		else
			printf "FunctionFS %-3s: not mounted\n" "$F"
		fi
	done

	if IS_RUNNING adbd; then
		printf "adbd: running\n"
	else
		printf "adbd: stopped\n"
	fi

	if IS_RUNNING umtprd; then
		printf "umtprd: running\n"
	else
		printf "umtprd: stopped\n"
	fi
}

CMD_RESUME() {
	[ -n "$UDC" ] || exit 0
	REPAIR_AFTER_RESUME
}

CMD_DISABLE() {
	STOP_GADGET
}

# Internal watchdog entry (do not call directly)
if [ "$1" = "__watchdog" ]; then
	WATCHDOG_LOOP
	exit 0
fi

ACTION="$1"
case "$ACTION" in
	start) CMD_START ;;
	stop) CMD_STOP ;;
	status) CMD_STATUS ;;
	resume) CMD_RESUME ;;
	disable) CMD_DISABLE ;;
	*)
		printf "Usage: %s {start|stop|status|resume|disable}\n" "$0" >&2
		exit 2
		;;
esac
