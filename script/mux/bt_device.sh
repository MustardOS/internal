#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "BTDEVICE" "Bluetooth device management starting"

BT_DIR="$MUOS_CONF_GLOBAL/bluetooth"
BT_PAIRED="$BT_DIR/paired"
BT_DEVICE_LOCK="$BT_DIR/device.lock"

mkdir -p "$BT_DIR"

DO_LIST() {
	if [ -f "$BT_DEVICE_LOCK" ]; then
		LOCK_PID=$(cat "$BT_DEVICE_LOCK" 2>/dev/null)
		if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
			LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Device list already in progress (PID %s) - skipping" "$LOCK_PID")"
			exit 0
		fi
		rm -f "$BT_DEVICE_LOCK"
	fi
	printf "%s" "$$" >"$BT_DEVICE_LOCK"
	trap 'rm -f "$BT_DEVICE_LOCK"' EXIT
	LOG_INFO "$0" 0 "BTDEVICE" "Listing paired Bluetooth devices"

	if ! timeout 3 bluetoothctl show >/dev/null 2>&1; then
		LOG_WARN "$0" 0 "BTDEVICE" "bluetoothd not ready - skipping list update"
		: >"$BT_PAIRED"
		return 0
	fi

	CONNECTED_MACS=$(timeout 5 bluetoothctl devices Connected 2>/dev/null | awk '{ print $2 }')

	TMP_BT_PAIR="$BT_DIR/paired.tmp.$$"
	: >"$TMP_BT_PAIR"

	{
		timeout 5 bluetoothctl devices Paired 2>/dev/null
		timeout 5 bluetoothctl devices Trusted 2>/dev/null
		timeout 5 bluetoothctl devices Connected 2>/dev/null
	} | awk '!seen[$2]++' | while IFS= read -r LINE; do
		MAC=$(printf "%s" "$LINE" | awk '{ print $2 }')
		NAME=$(printf "%s" "$LINE" | cut -d' ' -f3-)

		[ -z "$MAC" ] && continue

		# Skip "Modalias" companion entries that sometimes get created
		case "$NAME" in Modalias:*) continue ;; esac
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

	# When the same device name appears both connected and disconnected, the
	# disconnected entry is a stale pairing so we'll remove the crusty pair.
	CONNECTED_NAMES=$(awk '$2 == 1' "$TMP_BT_PAIR" | cut -d' ' -f3-)
	if [ -n "$CONNECTED_NAMES" ]; then
		TMP_DEDUP="$BT_DIR/paired.dedup.tmp.$$"
		: >"$TMP_DEDUP"
		while IFS= read -r LINE; do
			ENTRY_MAC=$(printf "%s" "$LINE" | awk '{print $1}')
			ENTRY_CONN=$(printf "%s" "$LINE" | awk '{print $2}')
			ENTRY_NAME=$(printf "%s" "$LINE" | cut -d' ' -f3-)
			if [ "$ENTRY_CONN" = "0" ] && printf "%s\n" "$CONNECTED_NAMES" | grep -qxF "$ENTRY_NAME" 2>/dev/null; then
				LOG_DEBUG "$0" 0 "BTDEVICE" "$(printf "Removing stale pairing '%s' (%s)" "$ENTRY_NAME" "$ENTRY_MAC")"
				timeout 5 bluetoothctl remove "$ENTRY_MAC" >/dev/null 2>&1
				MAC_CLEAN=$(printf "%s" "$ENTRY_MAC" | tr ':' '_')
				rm -f "$BT_DIR/alias_$MAC_CLEAN" "$BT_DIR/type_$MAC_CLEAN"
			else
				printf "%s\n" "$LINE" >>"$TMP_DEDUP"
			fi
		done <"$TMP_BT_PAIR"
		mv -f "$TMP_DEDUP" "$TMP_BT_PAIR"
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

	bluetoothctl pair "$MAC" >/dev/null 2>&1
	bluetoothctl trust "$MAC" >/dev/null 2>&1

	if bluetoothctl connect "$MAC" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Connected to '%s'" "$MAC")"

		MAC_CLEAN=$(printf "%s" "$MAC" | tr ':' '_')
		STORED_TYPE=$(cat "$BT_DIR/type_$MAC_CLEAN" 2>/dev/null)
		IS_AUDIO=0
		if [ -n "$STORED_TYPE" ]; then
			case "$STORED_TYPE" in audio-*) IS_AUDIO=1 ;; esac
		else
			BT_ICON=$(bluetoothctl info "$MAC" 2>/dev/null | awk -F': ' '/^\tIcon:/ { print $2; exit }')
			case "$BT_ICON" in audio-*) IS_AUDIO=1 ;; esac
		fi

		if [ "$IS_AUDIO" -eq 1 ]; then
			"$(dirname "$0")/audio_sink.sh" set-bt "$MAC" &
		fi
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

	MAC_CLEAN=$(printf "%s" "$MAC" | tr ':' '_')
	STORED_TYPE=$(cat "$BT_DIR/type_$MAC_CLEAN" 2>/dev/null)

	IS_AUDIO=0

	if [ -n "$STORED_TYPE" ]; then
		case "$STORED_TYPE" in audio-*) IS_AUDIO=1 ;; esac
	else
		BT_ICON=$(bluetoothctl info "$MAC" 2>/dev/null | awk -F': ' '/^\tIcon:/ { print $2; exit }')
		case "$BT_ICON" in audio-*) IS_AUDIO=1 ;; esac
	fi

	if timeout 5 bluetoothctl disconnect "$MAC" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "BTDEVICE" "$(printf "Disconnected from '%s'" "$MAC")"
	else
		LOG_WARN "$0" 0 "BTDEVICE" "$(printf "Disconnect from '%s' timed out or failed; continuing" "$MAC")"
	fi

	[ "$IS_AUDIO" -eq 1 ] && "$(dirname "$0")/audio_sink.sh" set-builtin &
}

DO_FORGET() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "BTDEVICE" "No MAC address provided for forget"
		exit 1
	}

	LOG_INFO "$0" 0 "BTDEVICE" "$(printf "Forgetting device '%s'" "$MAC")"

	bluetoothctl untrust "$MAC" >/dev/null 2>&1
	timeout 5 bluetoothctl disconnect "$MAC" >/dev/null 2>&1 || true
	bluetoothctl remove "$MAC" >/dev/null 2>&1

	MAC_CLEAN=$(printf "%s" "$MAC" | tr ':' '_')
	rm -f "$BT_DIR/alias_$MAC_CLEAN" "$BT_DIR/type_$MAC_CLEAN"

	if [ -f "$BT_PAIRED" ]; then
		TMP="$BT_DIR/paired.tmp.$$"
		grep -v "^$MAC " "$BT_PAIRED" >"$TMP" 2>/dev/null || true
		mv -f "$TMP" "$BT_PAIRED"
	fi

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

	[ -f "$BT_PAIRED" ] || {
		LOG_INFO "$0" 0 "BTDEVICE" "No managed devices to auto-connect"
		return 0
	}

	while IFS= read -r LINE; do
		MAC=$(printf "%s" "$LINE" | awk '{ print $1 }')
		[ -z "$MAC" ] && continue
		bluetoothctl trust "$MAC" >/dev/null 2>&1
	done <"$BT_PAIRED"

	(
		printf "scan on\n"
		sleep 8
		printf "scan off\n"
	) | timeout 15 bluetoothctl >/dev/null 2>&1

	while IFS= read -r LINE; do
		MAC=$(printf "%s" "$LINE" | awk '{ print $1 }')
		[ -z "$MAC" ] && continue
		LOG_DEBUG "$0" 0 "BTDEVICE" "$(printf "Auto-connecting to '%s'" "$MAC")"
		bluetoothctl connect "$MAC" >/dev/null 2>&1 &
	done <"$BT_PAIRED"

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
