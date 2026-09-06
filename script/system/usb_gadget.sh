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

PID_FILE="$MUOS_RUN_DIR/usb_gadget.pid"
UMTPRD_CONF_SOURCE=${UMTPRD_CONF_SOURCE:-"$MUOS_SHARE_DIR/conf/rootfs/umtprd.conf"}
UMTPRD_CONF_TARGET=${UMTPRD_CONF_TARGET:-"/etc/umtprd/umtprd.conf"}

GET_USB_FUNCTION() {
	case "$(GET_VAR "config" "settings/advanced/usb_function")" in
		2) echo mtp ;;
		1) echo adb ;;
		*) echo none ;;
	esac
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
	[ -d "/sys/kernel/config" ] || mount -t configfs none "/sys/kernel/config" 2>/dev/null
}

RESOLVE_UDC() {
	[ -n "$UDC" ] && [ -e "/sys/class/udc/$UDC" ] && return 0

	for UDC_PATH in /sys/class/udc/*; do
		[ -e "$UDC_PATH" ] || continue
		UDC=${UDC_PATH##*/}
		return 0
	done

	UDC=
	return 1
}

UNBIND_UDC() {
	[ -e "$GADGET/UDC" ] || return 0

	if [ -n "$(cat "$GADGET/UDC" 2>/dev/null)" ]; then
		printf '' >"$GADGET/UDC" 2>/dev/null
		sleep 0.1
	fi
}

BIND_UDC() {
	RESOLVE_UDC || return 1
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

	mkdir -p "$GFUN/ffs.$F" || return 1
	[ -L "$GCFG/ffs.$F" ] || ln -s "$GFUN/ffs.$F" "$GCFG/ffs.$F" || return 1

	mkdir -p "$FFS_ROOT/$F" || return 1
	if ! IS_MOUNTED "$FFS_ROOT/$F"; then
		mount -t functionfs "$F" "$FFS_ROOT/$F" || return 1
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
		adb)
			[ -x /usr/bin/adbd ] || return 1
			IS_RUNNING adbd || /usr/bin/adbd &
			;;
		mtp)
			[ -x /usr/bin/umtprd ] || return 1
			UPDATE_UMTPRD_CONF || {
				LOG_ERROR "$0" 0 "USB" "Unable to prepare the uMTP Responder configuration"
				return 1
			}
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

FUNCTION_AVAILABLE() {
	case "$1" in
		adb) [ -x /usr/bin/adbd ] ;;
		mtp) [ -x /usr/bin/umtprd ] ;;
		none) return 0 ;;
		*) return 1 ;;
	esac
}

FUNCTION_READY() {
	F="$1"
	DAEMON_UP "$F" || return 1
	[ -e "$FFS_ROOT/$F/ep0" ] || return 1
	[ -e "$FFS_ROOT/$F/ep1" ] || return 1
	[ -e "$FFS_ROOT/$F/ep2" ] || return 1
	[ "$F" != mtp ] || [ -e "$FFS_ROOT/$F/ep3" ]
}

WAIT_FUNCTION_READY() {
	F="$1"
	FFS_WAIT=30
	while [ "$FFS_WAIT" -gt 0 ]; do
		FUNCTION_READY "$F" && return 0
		sleep 0.1
		FFS_WAIT=$((FFS_WAIT - 1))
	done

	LOG_ERROR "$0" 0 "USB" "$(printf "FunctionFS '%s' did not become ready" "$F")"
	return 1
}

SWITCH_TO() {
	TGT="$1"
	OTHER="$([ "$TGT" = adb ] && echo mtp || echo adb)"

	if [ "$(CURRENT_FUNCTION)" = "$TGT" ] && IS_MOUNTED "$FFS_ROOT/$TGT" && FUNCTION_READY "$TGT"; then
		BIND_UDC
		return 0
	fi

	UNBIND_UDC
	STOP_DAEMONS
	UMOUNT_FFS "$OTHER"

	MOUNT_FFS "$TGT" || return 1
	START_DAEMON_PROC "$TGT" || return 1
	WAIT_FUNCTION_READY "$TGT" || return 1
	BIND_UDC
}

UPDATE_UMTPRD_CONF() {
	[ -r "$UMTPRD_CONF_SOURCE" ] || return 1
	mkdir -p "${UMTPRD_CONF_TARGET%/*}" || return 1
	UMTPRD_CONF_TEMP="$UMTPRD_CONF_TARGET.tmp.$$"
	rm -f "$UMTPRD_CONF_TEMP"
	cp -f "$UMTPRD_CONF_SOURCE" "$UMTPRD_CONF_TEMP" || return 1
	chmod 0644 "$UMTPRD_CONF_TEMP" || {
		rm -f "$UMTPRD_CONF_TEMP"
		return 1
	}

	_VID="$(USB_VID)"
	_PID="$(USB_PID)"
	_SER="$(USB_SERIAL)"
	_MFR="$(USB_MANUFACTURER)"
	_PRD="$(USB_PRODUCT)"
	_FWV="$(FIRMWARE_VERSION)"

	if [ "$(GET_VAR "device" "storage/sdcard/active")" -eq 1 ]; then
		_SDCARD_EXPR='s|^#storage "/mnt/sdcard"|storage "/mnt/sdcard"|'
	else
		_SDCARD_EXPR='s|^storage "/mnt/sdcard"|#storage "/mnt/sdcard"|'
	fi

	sed -i \
		-e "$_SDCARD_EXPR" \
		-e "s/^usb_vendor_id .*/usb_vendor_id \"$_VID\"/" \
		-e "s/^usb_product_id .*/usb_product_id \"$_PID\"/" \
		-e "s/^serial .*/serial \"$_SER\"/" \
		-e "s/^manufacturer .*/manufacturer \"$_MFR\"/" \
		-e "s/^product .*/product \"$_PRD\"/" \
		-e "s/^firmware_version .*/firmware_version \"$_FWV\"/" \
		"$UMTPRD_CONF_TEMP" || {
		rm -f "$UMTPRD_CONF_TEMP"
		return 1
	}

	mv -f "$UMTPRD_CONF_TEMP" "$UMTPRD_CONF_TARGET"
}

START_GADGET() {
	ENSURE_CONFIG_FS
	CREATE_GADGET_SHELL

	case "$USB_FUNCTION" in
		adb | mtp)
			MOUNT_FFS "$USB_FUNCTION" || return 1
			START_DAEMON_PROC "$USB_FUNCTION" || return 1
			WAIT_FUNCTION_READY "$USB_FUNCTION" || return 1
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
				MOUNT_FFS "$USB_FUNCTION" || return 1
				START_DAEMON_PROC "$USB_FUNCTION" || return 1
				WAIT_FUNCTION_READY "$USB_FUNCTION" || return 1
				;;
		esac
		BIND_UDC
	fi
}

READ_UDC_STATE() {
	# Typical values: "not attached", "powered", "attached", "configured"
	if RESOLVE_UDC && [ -r "/sys/class/udc/$UDC/state" ]; then
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
			FUNCTION_AVAILABLE "$USB_FUNCTION" || {
				LOG_ERROR "$0" 0 "USB" "$(printf "USB function '%s' is unavailable on this rootfs" "$USB_FUNCTION")"
				return 2
			}
			if [ ! -d "$GADGET" ]; then
				ENSURE_CONFIG_FS
				CREATE_GADGET_SHELL
				SWITCH_TO "$USB_FUNCTION"
			else
				SWITCH_TO "$USB_FUNCTION"
			fi
			;;
		*) ;;
	esac
}

ACQUIRE_PIDFILE() {
	mkdir -p "$(dirname "$PID_FILE")" 2>/dev/null

	set -C
	if printf '%s\n' "$$" >"$PID_FILE" 2>/dev/null; then
		set +C
		trap 'rm -f "$PID_FILE"; exit 0' INT HUP TERM EXIT
		return 0
	fi
	set +C

	if [ -r "$PID_FILE" ]; then
		OLD_PID="$(cat "$PID_FILE" 2>/dev/null)"
		if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
			return 1
		fi
	fi

	rm -f "$PID_FILE" 2>/dev/null

	set -C
	if printf '%s\n' "$$" >"$PID_FILE" 2>/dev/null; then
		set +C
		trap 'rm -f "$PID_FILE"; exit 0' INT HUP TERM EXIT
		return 0
	fi
	set +C

	return 1
}

WATCHDOG_LOOP() {
	ACQUIRE_PIDFILE || exit 0

	INTERVAL="1"
	STALL_REBIND_SECS="10"
	STALL_COUNT=0

	ENSURE_DESIRED_STATE
	ENSURE_RESULT=$?
	[ "$ENSURE_RESULT" -ne 2 ] || exit 1

	while :; do
		RESOLVE_UDC || {
			sleep "$INTERVAL"
			continue
		}

		ENSURE_DESIRED_STATE
		ENSURE_RESULT=$?
		[ "$ENSURE_RESULT" -ne 2 ] || exit 1
		STATE="$(READ_UDC_STATE)"

		case "$STATE" in
			configured | "configured with interfaces")
				STALL_COUNT=0
				;;
			"not attached")
				STALL_COUNT=0
				[ -n "$(cat "$GADGET/UDC" 2>/dev/null)" ] || BIND_UDC
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
	REQUESTED_FUNCTION=$(GET_USB_FUNCTION)
	FUNCTION_AVAILABLE "$REQUESTED_FUNCTION" || {
		printf "usb_gadgetd: %s is unavailable on this rootfs\n" "$REQUESTED_FUNCTION" >&2
		return 1
	}

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
			printf "usb_gadgetd: stale pid (pid %s)\n" "$P"
		fi
	fi

	rm -f "$PID_FILE" 2>/dev/null
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

	if ! RESOLVE_UDC; then
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
