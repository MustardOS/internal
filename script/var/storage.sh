#!/bin/sh

[ -n "${MUOS_STORAGE_LOADED-}" ] && return 0
MUOS_STORAGE_LOADED=1
[ -n "${MUOS_DISPLAY_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/display.sh"
[ -n "${MUOS_RUNTIME_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/runtime.sh"

SECONDARY_DEVICE() {
	case "$(GET_VAR "device" "board/name"):$(GET_VAR "config" "danger/emmc")" in
		tui-*:1) printf '%s\n' mmcblk2 ;;
		*) GET_VAR "device" "storage/sdcard/dev" ;;
	esac
}

READ_FIRST_LINE() {
	[ -r "$1" ] || return 1
	READ_LINE=
	IFS= read -r READ_LINE <"$1" || return 1
	printf '%s\n' "$READ_LINE"
}

ENSURE_REMOVED_SYNC() {
	REMOVE_PATH=$1
	REMOVE_COUNT=0

	while [ -e "$REMOVE_PATH" ] && [ "$REMOVE_COUNT" -lt 10 ]; do
		rm -f -- "$REMOVE_PATH" 2>/dev/null
		[ -e "$REMOVE_PATH" ] || break
		REMOVE_COUNT=$((REMOVE_COUNT + 1))
		sleep 0.1
	done
}

SET_PIXEL_USB_ROLE() {
	[ "$(GET_VAR "device" "board/name")" = "rk-pixel-2" ] || return 0

	case "${1:-$(GET_VAR "config" "settings/advanced/usb_function")}" in
		0) USB_ROLE="otg" ;;
		1 | 2) USB_ROLE="peripheral" ;;
		*) return 0 ;;
	esac

	for OTG_MODE in /sys/devices/platform/*/*usb2-phy*/otg_mode; do
		[ -w "$OTG_MODE" ] || continue
		[ "$(cat "$OTG_MODE" 2>/dev/null)" = "$USB_ROLE" ] && return 0
		printf "%s" "$USB_ROLE" >"$OTG_MODE" || return 1
		LOG_INFO "$0" 0 "USB" "$(printf "Pixel 2 USB role set: %s" "$USB_ROLE")"
		return 0
	done

	LOG_WARN "$0" 0 "USB" "Pixel 2 USB role control not found"
	return 1
}

REMOVE_RUNTIME_FILES() {
	for RUNTIME_FILE in ra_no_load ra_autoload_once.cfg; do
		ENSURE_REMOVED_SYNC "/tmp/$RUNTIME_FILE"
	done

	ENSURE_REMOVED_SYNC "$CON_GO"
	ENSURE_REMOVED_SYNC "$FLT_GO"
	ENSURE_REMOVED_SYNC "$OVL_GO"
	ENSURE_REMOVED_SYNC "$OVO_GO"
	ENSURE_REMOVED_SYNC "$RAC_GO"
	ENSURE_REMOVED_SYNC "$SHD_GO"
	ENSURE_REMOVED_SYNC "$SPL_GO"
	ENSURE_REMOVED_SYNC "$MUOS_RUN_DIR/overlay.filter"
	ENSURE_REMOVED_SYNC "$MUOS_RUN_DIR/overlay.shader"
	ENSURE_REMOVED_SYNC "$MUOS_RUN_DIR/overlay.options"
}

RESET_LAUNCHER_FLAGS() {
	ENSURE_REMOVED_SYNC "$GOV_GO"
	ENSURE_REMOVED_SYNC "$CON_GO"
	ENSURE_REMOVED_SYNC "$FLT_GO"
	ENSURE_REMOVED_SYNC "$SHD_GO"
	ENSURE_REMOVED_SYNC "$OVO_GO"
	ENSURE_REMOVED_SYNC "$RAC_GO"
	ENSURE_REMOVED_SYNC "$SAA_GO"
	ENSURE_REMOVED_SYNC "$SAG_GO"
	ENSURE_REMOVED_SYNC "$SAR_GO"
}

RESET_APP_FLAGS() {
	ENSURE_REMOVED_SYNC "$GOV_GO"
	ENSURE_REMOVED_SYNC "$CON_GO"
}

WAIT_FOR_AUDIO_READY() {
	AUDIO_WAIT_MAX=${1:-100}
	AUDIO_WAIT=0

	LOG_INFO "$0" 0 "BOOTING" "Waiting for PipeWire initialisation"

	while [ "$AUDIO_WAIT" -lt "$AUDIO_WAIT_MAX" ]; do
		[ "$(GET_VAR "device" "audio/ready")" = "1" ] && return 0
		AUDIO_WAIT=$((AUDIO_WAIT + 1))
		sleep 0.1
	done

	LOG_WARN "$0" 0 "BOOTING" "PipeWire initialisation wait timed out"
	return 1
}

RESET_DPAD_MODE() {
	BOARD_STICK_VALUE=${1:-$(GET_VAR "device" "board/stick")}
	BOARD_NAME_VALUE=${2:-$(GET_VAR "device" "board/name")}
	DPAD_SWAP_PATH=${3:-$(GET_VAR "device" "board/swap")}

	IS_ONE "$BOARD_STICK_VALUE" && return 0

	case "$BOARD_NAME_VALUE" in
		rg*) printf "0" >"$DPAD_SWAP_PATH" ;;
		rk-pixel-2 | tui*) ENSURE_REMOVED_SYNC "$DPAD_SWAP_PATH" ;;
	esac
}

COPY_IF_AVAILABLE() {
	SETTING_NAME=$1
	CONTENT_FILE=$2
	FALLBACK_FILE=$3
	OUTPUT_FILE=$4

	if [ -e "$CONTENT_FILE" ]; then
		cat "$CONTENT_FILE" >"$OUTPUT_FILE"
	elif [ -e "$FALLBACK_FILE" ]; then
		cat "$FALLBACK_FILE" >"$OUTPUT_FILE"
	else
		LOG_INFO "$0" 0 "FRONTEND" "No $SETTING_NAME file found for launched content"
	fi
}

COPY_CONTENT_SETTINGS() {
	CONTENT_BASE=$1
	CONTENT_DIR=$2

	COPY_IF_AVAILABLE "governor" "$CONTENT_DIR/$CONTENT_BASE.gov" "$CONTENT_DIR/core.gov" "$GOV_GO"
	COPY_IF_AVAILABLE "control" "$CONTENT_DIR/$CONTENT_BASE.con" "$CONTENT_DIR/core.con" "$CON_GO"
	COPY_IF_AVAILABLE "retroarch" "$CONTENT_DIR/$CONTENT_BASE.rac" "$CONTENT_DIR/core.rac" "$RAC_GO"
	COPY_IF_AVAILABLE "filter" "$CONTENT_DIR/$CONTENT_BASE.flt" "$CONTENT_DIR/core.flt" "$FLT_GO"
	COPY_IF_AVAILABLE "shader" "$CONTENT_DIR/$CONTENT_BASE.shd" "$CONTENT_DIR/core.shd" "$SHD_GO"
}

APPLY_OPTIONAL_FILE() {
	SOURCE_FILE=$1
	TARGET_FILE=$2
	DESCRIPTION=$3

	if [ -s "$SOURCE_FILE" ]; then
		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Applying %s from '%s' to '%s'" "$DESCRIPTION" "$SOURCE_FILE" "$TARGET_FILE")"
		cat "$SOURCE_FILE" >"$TARGET_FILE"
		return $?
	fi

	LOG_WARN "$0" 0 "LAUNCH" "$(printf "Missing %s file: '%s'" "$DESCRIPTION" "$SOURCE_FILE")"
	return 1
}

RESTORE_DPAD_AND_LEDS() {
	RESTORE_BOARD_NAME=${1:-$(GET_VAR "device" "board/name")}
	RESTORE_DPAD_SWAP=${2:-$(GET_VAR "device" "board/swap")}
	RESTORE_LED_NORMAL=${3:-$(GET_VAR "device" "led/normal")}
	RESTORE_LED_STATE=${4:-"$MUOS_RUN_DIR/work_led_state"}

	[ "$(GET_VAR "device" "board/stick")" = "1" ] && return 0

	case "$RESTORE_BOARD_NAME" in
		rg*)
			LOG_DEBUG "$0" 0 "LAUNCH" "Resetting DPAD swap and LED state for rg* board"
			printf "0" >"$RESTORE_DPAD_SWAP"
			[ -e "$MUOS_RUN_DIR/quiet_halt" ] || printf "1" >"$RESTORE_LED_NORMAL"
			printf "1" >"$RESTORE_LED_STATE"
			;;
		rk-pixel-2 | tui*)
			ENSURE_REMOVED_SYNC "$RESTORE_DPAD_SWAP"
			;;
		*) ;;
	esac
}

RESTORE_FRAMEBUFFER_MODE() {
	DEVICE_MODE_VALUE=${1:-$(GET_VAR "config" "boot/device_mode")}
	INTERNAL_WIDTH=${2:-$(GET_VAR "device" "screen/internal/width")}
	INTERNAL_HEIGHT=${3:-$(GET_VAR "device" "screen/internal/height")}
	EXTERNAL_WIDTH=${4:-$(GET_VAR "device" "screen/external/width")}
	EXTERNAL_HEIGHT=${5:-$(GET_VAR "device" "screen/external/height")}

	if IS_ONE "$DEVICE_MODE_VALUE"; then
		# Keep whatever buffering the HDMI switch settled on
		EXTERNAL_BUFFERS=$(GET_VAR "device" "screen/external/buffers")
		case "$EXTERNAL_BUFFERS" in
			1 | 2 | 3 | 4) ;;
			*) EXTERNAL_BUFFERS=2 ;;
		esac

		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Switching framebuffer to external %sx%s@32 x%s" "$EXTERNAL_WIDTH" "$EXTERNAL_HEIGHT" "$EXTERNAL_BUFFERS")"
		FB_SWITCH "$EXTERNAL_WIDTH" "$EXTERNAL_HEIGHT" 32 "$EXTERNAL_BUFFERS"
	else
		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Switching framebuffer to internal %sx%s@32" "$INTERNAL_WIDTH" "$INTERNAL_HEIGHT")"
		FB_SWITCH "$INTERNAL_WIDTH" "$INTERNAL_HEIGHT" 32
	fi
}

RUN_SYNCTHING_SCAN() {
	USE_SYNCTHING_VALUE=${1:-$(GET_VAR "config" "web/syncthing")}
	AUTO_SCAN_VALUE=${2:-$(GET_VAR "config" "syncthing/auto_scan")}
	NET_STATE_PATH=${3:-$(GET_VAR "device" "network/state")}

	IS_ONE "$USE_SYNCTHING_VALUE" || return 0
	IS_ONE "$AUTO_SCAN_VALUE" || return 0
	[ -r "$NET_STATE_PATH" ] || return 0
	[ "$(READ_FIRST_LINE "$NET_STATE_PATH")" = "up" ] || return 0

	SYNCTHING_CONFIG="$MUOS_STORE_DIR/syncthing/config.xml"
	[ -r "$SYNCTHING_CONFIG" ] || {
		LOG_WARN "$0" 0 "LAUNCH" "Syncthing config not readable; skipping folder rescan"
		return 0
	}

	SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$SYNCTHING_CONFIG")
	[ -n "$SYNCTHING_API" ] || {
		LOG_WARN "$0" 0 "LAUNCH" "Syncthing API key missing; skipping folder rescan"
		return 0
	}

	LOG_INFO "$0" 0 "LAUNCH" "Triggering Syncthing folder rescan"
	SYNCTHING_PORT=$(GET_WEB_PORT "syncthing_port" 7070)

	if command -v curl >/dev/null 2>&1; then
		curl --silent --show-error --max-time 5 \
			-X POST \
			-H "X-API-Key: $SYNCTHING_API" \
			"http://localhost:$SYNCTHING_PORT/rest/db/scan" >/dev/null 2>&1 ||
			LOG_WARN "$0" 0 "LAUNCH" "Syncthing folder rescan failed"
	fi
}

MUOS_MKE2FS="/opt/muos/bin/mke2fs"
MUOS_MKE2FS_CONF="/opt/muos/share/conf/mke2fs.conf"

EXFAT_NATIVE_BUILTIN() {
	if zcat /proc/config.gz 2>/dev/null | grep -q "^CONFIG_EXFAT_FS=y"; then
		return 0
	fi

	grep -qw exfat /proc/filesystems 2>/dev/null &&
		! grep -q "^exfat " /proc/modules 2>/dev/null
}

EXFAT_NATIVE_READY() {
	grep -qw exfat /proc/filesystems 2>/dev/null && return 0

	modprobe -q exfat 2>/dev/null
	grep -qw exfat /proc/filesystems 2>/dev/null
}

MOUNT_FILESYSTEM() {
	MFS_TYPE=$1
	MFS_OPTIONS=$2
	MFS_DEVICE=$3
	MFS_TARGET=$4

	if [ "$MFS_TYPE" = exfat ] && EXFAT_NATIVE_READY; then
		mount -i -t "$MFS_TYPE" -o "$MFS_OPTIONS" "$MFS_DEVICE" "$MFS_TARGET"
	else
		mount -t "$MFS_TYPE" -o "$MFS_OPTIONS" "$MFS_DEVICE" "$MFS_TARGET"
	fi
}

FS_HAS_CASEFOLD() {
	[ -e /sys/fs/ext4/features/casefold ]
}

FS_CAN_MAKE() {
	case "$1" in
		ext2 | ext3 | ext4)
			[ -x "$MUOS_MKE2FS" ] && return 0
			;;
	esac

	command -v "mkfs.$1" >/dev/null 2>&1
}

MAKE_FILESYSTEM() {
	MKFS_TYPE="$1"
	MKFS_PART="$2"
	MKFS_LABEL="$3"

	case "$MKFS_TYPE" in
		ext2 | ext3 | ext4)
			MKFS_FOLD=""
			if [ "$MKFS_TYPE" = "ext4" ] && FS_HAS_CASEFOLD; then
				MKFS_FOLD="-O casefold -E encoding=utf8"
				LOG_INFO "$0" 0 "FILESYSTEM" "Kernel supports case folding, enabling it on $MKFS_PART"
			fi

			if [ -x "$MUOS_MKE2FS" ]; then
				if [ -f "$MUOS_MKE2FS_CONF" ]; then
					MKE2FS_CONFIG="$MUOS_MKE2FS_CONF" \
						"$MUOS_MKE2FS" -q -F -t "$MKFS_TYPE" $MKFS_FOLD -L "$MKFS_LABEL" "$MKFS_PART"
				else
					"$MUOS_MKE2FS" -q -F -t "$MKFS_TYPE" $MKFS_FOLD -L "$MKFS_LABEL" "$MKFS_PART"
				fi

				return "$?"
			fi

			mkfs."$MKFS_TYPE" -F -L "$MKFS_LABEL" "$MKFS_PART"
			;;
		exfat) mkfs.exfat -n "$MKFS_LABEL" "$MKFS_PART" ;;
		vfat) mkfs.vfat -F 32 -n "$MKFS_LABEL" "$MKFS_PART" ;;
		*) mkfs."$MKFS_TYPE" "$MKFS_PART" ;;
	esac
}
