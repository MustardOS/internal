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

	GET_VAR "config" "settings/general/colour" >"$(GET_VAR "device" "screen/colour")"
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

DEV_BOARD=$(GET_VAR "device" "board/name")
EMU_VER=

case "$DEV_BOARD" in
	rg*)
		EMU_VER="rg"
		case "$DEV_BOARD" in
			rg34xx-sp | rg35xx-sp)
				/opt/muos/script/device/lid.sh &
				;;
		esac
		;;
	tui*)
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

# Add device specific Retroarch Binary
RA_DIR="$MUOS_SHARE_DIR/emulator/retroarch"
RA_BIN="$RA_DIR/retroarch-${EMU_VER}"
RA_MD5="$RA_DIR/retroarch-${EMU_VER}.md5"
RA_TGT="/usr/bin/retroarch"

if [ -e "$RA_BIN" ]; then
	if [ -f "$RA_TGT" ]; then
		CURRENT_MD5=$(md5sum "$RA_TGT" | awk '{ print $1 }')
		if [ "$CURRENT_MD5" != "$RA_MD5" ]; then
			cp -f "$RA_BIN" "$RA_TGT"
			chmod +x "$RA_TGT"
		fi
	else
		cp -f "$RA_BIN" "$RA_TGT"
		chmod +x "$RA_TGT"
	fi
fi

# Add device specific PPSSPP Binary
PPSSPP_DIR="$MUOS_SHARE_DIR/emulator/ppsspp"
PPSSPP_BIN="$PPSSPP_DIR/PPSSPP"
PPSSPP_ARCHIVE="${PPSSPP_BIN}-${EMU_VER}.tar.gz"
PPSSPP_MD5="$PPSSPP_BIN-${EMU_VER}.md5"

if [ -e "$PPSSPP_ARCHIVE" ]; then
	EXPECTED_MD5=$(cat "$PPSSPP_MD5")

	CURRENT_MD5=""
	[ -f "$PPSSPP_BIN" ] && CURRENT_MD5=$(md5sum "$PPSSPP_BIN" | awk '{ print $1 }')

	if [ "$CURRENT_MD5" != "$EXPECTED_MD5" ]; then
		TMPDIR=$(mktemp -d "$PPSSPP_DIR/ppsspp-tmp.XXXXXX") || exit 1
		# Use gzip stdin to extract, no '-z' available in busybox tar.
		gzip -dc -- "$PPSSPP_ARCHIVE" | tar -xf - -C "$TMPDIR"

		# Find the extracted binary (PPSSPP-rg or PPSSPP-tui)
		SRC_BIN=$(find "$TMPDIR" -maxdepth 1 -type f -name 'PPSSPP-*' | head -n 1)

		if [ -n "$SRC_BIN" ]; then
			cp -f "$SRC_BIN" "$PPSSPP_BIN"
			chmod +x "$PPSSPP_BIN"
		else
			echo "Error: no PPSSPP-* binary found in archive $PPSSPP_ARCHIVE" >&2
		fi

		rm -rf "$TMPDIR"
	fi
fi

# Add device specific ScummVM binary
SCUMMVM_DIR="$MUOS_SHARE_DIR/emulator/scummvm"
SCUMMVM_BIN="$SCUMMVM_DIR/scummvm"
SCUMMVM_ARCHIVE="${SCUMMVM_BIN}-${EMU_VER}.tar.gz"
SCUMMVM_MD5="$SCUMMVM_BIN-${EMU_VER}.md5"

if [ -e "$SCUMMVM_ARCHIVE" ]; then
	EXPECTED_MD5=$(cat "$SCUMMVM_MD5")

	CURRENT_MD5=""
	[ -f "$SCUMMVM_BIN" ] && CURRENT_MD5=$(md5sum "$SCUMMVM_BIN" | awk '{ print $1 }')

	if [ "$CURRENT_MD5" != "$EXPECTED_MD5" ]; then
		TMPDIR=$(mktemp -d "$SCUMMVM_DIR/scummvm-tmp.XXXXXX") || exit 1
		# Use gzip stdin to extract, no '-z' available in busybox tar.
		gzip -dc -- "$SCUMMVM_ARCHIVE" | tar -xf - -C "$TMPDIR"

		# Find the extracted binary (scummvm-rg or scummvm-tui)
		SRC_BIN=$(find "$TMPDIR" -maxdepth 1 -type f -name 'scummvm-*' | head -n 1)

		if [ -n "$SRC_BIN" ]; then
			cp -f "$SRC_BIN" "$SCUMMVM_BIN"
			chmod +x "$SCUMMVM_BIN"
		else
			echo "Error: no scummvm-* binary found in archive $SCUMMVM_ARCHIVE" >&2
		fi

		rm -rf "$TMPDIR"
	fi
fi
