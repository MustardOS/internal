#!/bin/sh

. /opt/muos/script/var/func.sh

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf

if [ "$(GET_VAR "device" "board/debugfs")" -eq 1 ]; then
	mount -t debugfs debugfs /sys/kernel/debug
fi

if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
	/opt/muos/script/device/hdmi.sh
else
	/opt/muos/script/device/bright.sh R

	case "$(GET_VAR "config" "settings/advanced/brightness")" in
		3) /opt/muos/script/device/bright.sh "$(GET_VAR "device" "screen/bright")" ;;
		2) /opt/muos/script/device/bright.sh 90 ;;
		1) /opt/muos/script/device/bright.sh 35 ;;
		*) /opt/muos/script/device/bright.sh "$(GET_VAR "config" "settings/general/brightness")" ;;
	esac

	GET_VAR "config" "settings/colour/temperature" >"$(GET_VAR "device" "screen/colour")"
	SET_VAR "config" "settings/hdmi/scan" "0"
fi

if [ "$(GET_VAR "config" "settings/advanced/overdrive")" -eq 1 ]; then
	SET_VAR "device" "audio/max" "200"
else
	SET_VAR "device" "audio/max" "100"
fi

if [ "$(GET_VAR "config" "settings/advanced/thermal")" -eq 0 ]; then
	for ZONE in /sys/class/thermal/thermal_zone*; do
		[ -e "$ZONE/mode" ] && echo "disabled" >"$ZONE/mode"
	done
fi

rfkill unblock all 2>/dev/null

# Swap the speaker audio if set
/opt/muos/script/device/speaker.sh &

# Calibrate user setting joystick values if set
/opt/muos/script/device/joycal.sh &

BOARD_NAME=$(GET_VAR "device" "board/name")
EMU_VER=

case "$BOARD_NAME" in
	rg-vita*)
		EMU_VER="vita"
		;;
	rg*)
		EMU_VER="rg"
		case "$BOARD_NAME" in
			rg34xx-sp | rg35xx-sp)
				/opt/muos/script/device/lid.sh start &
				;;
		esac
		;;
	mgx* | tui*)
		EMU_VER="tui"

		# Create TrimUI Input folder
		mkdir -p "/tmp/trimui_inputd"

		# Modified GPU parameters
		echo 0 >/sys/module/pvrsrvkm/parameters/PVRDebugLevel

		# Some stupid TrimUI GPU shenanigans
		setalpha 0
		;;
	rk*)
		EMU_VER="rk"
		;;
esac

# Install a flat binary if its MD5 differs from the installed copy.
INSTALL_BIN() {
	SRC_BIN="$1"
	SRC_MD5="$2"
	TGT_BIN="$3"

	[ -e "$SRC_BIN" ] || return 0

	EXPECTED_MD5=$(cat "$SRC_MD5" 2>/dev/null) || return 0

	CURRENT_MD5=""
	[ -f "$TGT_BIN" ] && CURRENT_MD5=$(md5sum "$TGT_BIN" | awk '{ print $1 }')

	if [ "$CURRENT_MD5" != "$EXPECTED_MD5" ]; then
		cp -f "$SRC_BIN" "$TGT_BIN"
		chmod +x "$TGT_BIN"
	fi
}

# Install a binary packed inside a versioned tar.gz if its MD5 differs from the installed copy.
INSTALL_ARCHIVE() {
	ARCHIVE="$1"
	MD5_FILE="$2"
	INSTALL_DIR="$3"
	GLOB="$4"
	TGT_BIN="$5"

	[ -e "$ARCHIVE" ] || return 0

	EXPECTED_MD5=$(cat "$MD5_FILE" 2>/dev/null) || return 0

	CURRENT_MD5=""
	[ -f "$TGT_BIN" ] && CURRENT_MD5=$(md5sum "$TGT_BIN" | awk '{ print $1 }')

	if [ "$CURRENT_MD5" != "$EXPECTED_MD5" ]; then
		_INST_TMP=$(mktemp -d "${INSTALL_DIR}/tmp.XXXXXX") || return 1
		gzip -dc -- "$ARCHIVE" | tar -xf - -C "$_INST_TMP"

		SRC_BIN=$(find "$_INST_TMP" -maxdepth 1 -type f -name "$GLOB" | head -n 1)

		if [ -n "$SRC_BIN" ]; then
			cp -f "$SRC_BIN" "$TGT_BIN"
			chmod +x "$TGT_BIN"
		else
			echo "Error: no $GLOB binary found in $ARCHIVE" >&2
		fi

		rm -rf "$_INST_TMP"
	fi
}

RA_DIR="$MUOS_SHARE_DIR/emulator/retroarch"
INSTALL_BIN "$RA_DIR/retroarch-${EMU_VER}" "$RA_DIR/retroarch-${EMU_VER}.md5" "/usr/bin/retroarch" &

PPSSPP_DIR="$MUOS_SHARE_DIR/emulator/ppsspp"
INSTALL_ARCHIVE "${PPSSPP_DIR}/PPSSPP-${EMU_VER}.tar.gz" "${PPSSPP_DIR}/PPSSPP-${EMU_VER}.md5" "$PPSSPP_DIR" "PPSSPP-*" "${PPSSPP_DIR}/PPSSPP" &

SCUMMVM_DIR="$MUOS_SHARE_DIR/emulator/scummvm"
INSTALL_ARCHIVE "${SCUMMVM_DIR}/scummvm-${EMU_VER}.tar.gz" "${SCUMMVM_DIR}/scummvm-${EMU_VER}.md5" "$SCUMMVM_DIR" "scummvm-*" "${SCUMMVM_DIR}/scummvm" &

wait
