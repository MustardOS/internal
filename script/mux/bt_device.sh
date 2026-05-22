#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "BTDEVICE" "Bluetooth device management starting"

BT_DIR="$MUOS_CONF_GLOBAL/bluetooth"
BT_PAIRED="$BT_DIR/paired"

mkdir -p "$BT_DIR"

DO_LIST() {
	LOG_INFO "$0" 0 "BTDEVICE" "Listing paired Bluetooth devices"

	if ! bluetoothctl show >/dev/null 2>&1; then
		LOG_WARN "$0" 0 "BTDEVICE" "bluetoothd not ready - skipping list update"
		return 0
	fi

	CONNECTED_MACS=$(bluetoothctl devices Connected 2>/dev/null | awk '{ print $2 }')

	TMP_BT_PAIR="$BT_DIR/paired.tmp.$$"
	: >"$TMP_BT_PAIR"

	{
		bluetoothctl devices Paired 2>/dev/null
		bluetoothctl devices Trusted 2>/dev/null
		bluetoothctl devices Connected 2>/dev/null
	} | awk '!seen[$2]++' | while IFS= read -r LINE; do
		MAC=$(printf "%s" "$LINE" | awk '{ print $2 }')
		NAME=$(printf "%s" "$LINE" | cut -d' ' -f3-)

		[ -z "$MAC" ] && continue
		[ -z "$NAME" ] && NAME="$MAC"

		MAC_CLEAN=$(printf "%s" "$MAC" | tr ':' '_')
		ALIAS_FILE="$BT_DIR/alias_$MAC_CLEAN"
		if [ -f "$ALIAS_FILE" ]; then
			OUR_ALIAS=$(cat "$ALIAS_FILE" 2>/dev/null)
			[ -n "$OUR_ALIAS" ] && NAME="$OUR_ALIAS"
		fi

		CONNECTED=0
		if printf "%s\n" "$CONNECTED_MACS" | grep -qxF "$MAC" 2>/dev/null; then
			CONNECTED=1
		fi

		printf "%s %d %s\n" "$MAC" "$CONNECTED" "$NAME" >>"$TMP_BT_PAIR"
	done

	if [ -s "$BT_PAIRED" ]; then
		while IFS= read -r OLD_LINE; do
			OLD_MAC=$(printf "%s" "$OLD_LINE" | awk '{ print $1 }')
			[ -z "$OLD_MAC" ] && continue
			grep -q "^$OLD_MAC " "$TMP_BT_PAIR" 2>/dev/null && continue

			OLD_NAME=$(printf "%s" "$OLD_LINE" | cut -d' ' -f3-)
			CONN=0
			if printf "%s\n" "$CONNECTED_MACS" | grep -qxF "$OLD_MAC" 2>/dev/null; then
				CONN=1
			fi
			printf "%s %d %s\n" "$OLD_MAC" "$CONN" "$OLD_NAME" >>"$TMP_BT_PAIR"
		done <"$BT_PAIRED"
	fi

	if [ ! -s "$TMP_BT_PAIR" ]; then
		rm -f "$TMP_BT_PAIR"
		LOG_WARN "$0" 0 "BTDEVICE" "No managed devices found"
		return 0
	fi

	COUNT=$(wc -l <"$TMP_BT_PAIR" 2>/dev/null || printf 0)
	mv -f "$TMP_BT_PAIR" "$BT_PAIRED"
	LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Found %s managed device(s); list written to '%s'" "${COUNT:-0}" "$BT_PAIRED")"
}

DO_CONNECT() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for connect"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Connecting to '%s'" "$MAC")"

	if bluetoothctl connect "$MAC" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Connected to '%s'" "$MAC")"
		"$(dirname "$0")/audio_sink.sh" set-bt "$MAC" &
	else
		LOG_WARN "$0" 0 "BTDEVICE" "$(printf "Connection to '%s' may have failed" "$MAC")"
	fi
}

DO_DISCONNECT() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for disconnect"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Disconnecting from '%s'" "$MAC")"

	if bluetoothctl disconnect "$MAC" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Disconnected from '%s'" "$MAC")"
		"$(dirname "$0")/audio_sink.sh" set-builtin &
	else
		LOG_WARN "$0" 0 "BTDEVICE" "$(printf "Disconnect from '%s' may have failed" "$MAC")"
	fi
}

DO_FORGET() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for forget"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Forgetting device '%s'" "$MAC")"
	bluetoothctl remove "$MAC" >/dev/null 2>&1

	MAC_CLEAN=$(printf "%s" "$MAC" | tr ':' '_')
	rm -f "$BT_DIR/alias_$MAC_CLEAN" "$BT_DIR/type_$MAC_CLEAN"

	LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Device '%s' removed" "$MAC")"
}

DO_INFO() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for info"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Fetching info for '%s'" "$MAC")"

	BT_INFO_FILE="$BT_DIR/device_info"
	BT_RAW=$(bluetoothctl info "$MAC" 2>/dev/null)

	{
		ALIAS=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tAlias:/ { print $2; exit }')
		NAME=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tName:/ { print $2; exit }')
		MAC_CLEAN_INFO=$(printf "%s" "$MAC" | tr ':' '_')
		OUR_ALIAS=$(cat "$BT_DIR/alias_$MAC_CLEAN_INFO" 2>/dev/null)

		printf "Name: %s\n" "${OUR_ALIAS:-${ALIAS:-${NAME:-$MAC}}}"

		ICON=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tIcon:/ { print $2; exit }')
		CLASS=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tClass:/ { print $2; exit }')
		UUIDS=$(printf "%s" "$BT_RAW" | sed -n 's/^\tUUID:.*(\([0-9a-f-]*\)).*/\1/p' | cut -c1-8 | sort -u | tr '\n' ' ')

		[ -n "$ICON" ] && printf "Icon: %s\n" "$ICON"
		[ -n "$CLASS" ] && printf "Class: %s\n" "$CLASS"
		[ -n "$UUIDS" ] && printf "UUIDs: %s\n" "$UUIDS"

		CONNECTED=$(printf "%s" "$BT_RAW" | awk -F': ' '/^\tConnected:/ { print $2; exit }')
		[ -n "$CONNECTED" ] && printf "Connected: %s\n" "$CONNECTED"

		BATTERY=$(printf "%s" "$BT_RAW" | awk -F'[()]' '/^\tBattery Percentage:/ { print $2 "%"; exit }')

		if [ -z "$BATTERY" ]; then
			MAC_CLEAN=$(printf "%s" "$MAC" | tr -d ':')
			for PS_DIR in /sys/class/power_supply/*; do
				case "$PS_DIR" in
					*"$MAC_CLEAN"* | *"$MAC"*)
						CAP=$(cat "$PS_DIR/capacity" 2>/dev/null)
						[ -n "$CAP" ] && BATTERY="${CAP}%" && break
						;;
				esac
			done
		fi

		[ -n "$BATTERY" ] && printf "Battery: %s\n" "$BATTERY"
	} >"$BT_INFO_FILE"

	LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Device info written to '%s'" "$BT_INFO_FILE")"
}

DO_ALIAS() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for alias"
		exit 1
	}

	ALIAS="$2"
	[ -z "$ALIAS" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No alias provided for alias"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Setting alias for '%s' to '%s'" "$MAC" "$ALIAS")"

	MAC_CLEAN=$(printf "%s" "$MAC" | tr ':' '_')
	printf "%s" "$ALIAS" >"$BT_DIR/alias_$MAC_CLEAN"

	HCI_DEV=$(hciconfig 2>/dev/null | awk -F: '/^hci[0-9]/ { print $1; exit }')
	HCI_DEV="${HCI_DEV:-hci0}"

	timeout 2 busctl set-property org.bluez "/org/bluez/$HCI_DEV/dev_$MAC_CLEAN" \
		org.bluez.Device1 Alias s "$ALIAS" 2>/dev/null

	LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Alias saved for '%s'" "$MAC")"
}

DO_AUTOCONNECT() {
	AUTOCONNECT=$(GET_VAR "config" "bluetooth/autoconnect")

	if [ "${AUTOCONNECT:-0}" -ne 1 ]; then
		LOG_INFO "$0" 0 "BTDEVICE" "Auto-connect disabled - skipping"
		return 0
	fi

	LOG_INFO "$0" 0 "BTDEVICE" "Auto-connecting to trusted paired devices"

	bluetoothctl devices Paired 2>/dev/null | while IFS= read -r LINE; do
		MAC=$(printf "%s" "$LINE" | awk '{ print $2 }')
		[ -z "$MAC" ] && continue
		LOG_DEBUG "$0" 0 "BTDEVICE" "$(printf "Auto-connecting to '%s'" "$MAC")"
		bluetoothctl connect "$MAC" >/dev/null 2>&1 &
	done

	LOG_SUCCESS "$0" 0 "BTDEVICE" "Auto-connect sequence initiated"
}

case "${1:-}" in
	list) DO_LIST ;;
	connect) DO_CONNECT "$2" ;;
	disconnect) DO_DISCONNECT "$2" ;;
	forget) DO_FORGET "$2" ;;
	info) DO_INFO "$2" ;;
	alias) DO_ALIAS "$2" "$3" ;;
	autoconnect) DO_AUTOCONNECT ;;
	*)
		printf "Usage: %s {list|connect <mac>|disconnect <mac>|forget <mac>|info <mac>|alias <mac> <name>|autoconnect}\n" "$0"
		exit 1
		;;
esac
