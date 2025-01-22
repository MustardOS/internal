#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "retroarch"

MESSAGE() {
	_TITLE=$1
	_MESSAGE=$2
	_FORM=$(
		cat <<EOF
$_TITLE

$_MESSAGE
EOF
	)
	/opt/muos/extra/muxstart 0 "$_FORM" && sleep "$3"
}

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
DOUK="$F_PATH/.Cave Story (En)/Doukutsu.exe"

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/nxe.log"

RA_CONF=/run/muos/storage/info/config/retroarch.cfg

# Include default button mappings from retroarch.device.cfg. (Settings
# in the retroarch.cfg will take precedence. Modified settings will save
# to the main retroarch.cfg, not the included retroarch.device.cfg.)
sed -n -e '/^#include /!p' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.device.cfg"' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.resolution.cfg"' \
	-i "$RA_CONF"

if [ "$(GET_VAR "kiosk" "content/retroarch")" -eq 1 ] 2>/dev/null; then
	sed -i 's/^kiosk_mode_enable = "false"$/kiosk_mode_enable = "true"/' "$RA_CONF"
else
	sed -i 's/^kiosk_mode_enable = "true"$/kiosk_mode_enable = "false"/' "$RA_CONF"
fi

if [ -e "$DOUK" ]; then
	retroarch -v -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$DOUK" &
	RA_PID=$!
else
	CZ_NAME="Cave Story (En).zip"
	CAVE_URL="https://bot.libretro.com/assets/cores/Cave Story/$CZ_NAME"
	BIOS_FOLDER="/run/muos/storage/bios/"

	if [ -e "$BIOS_FOLDER$CZ_NAME" ]; then
		echo "$CZ_NAME exists at $BIOS_FOLDER" >>"$LOGPATH"
	else
		echo "$CZ_NAME not found in $BIOS_FOLDER" >>"$LOGPATH"
		## Is this thing on(line)?
		check_internet() {
			echo "Pinging github.com" >>"$LOGPATH"
			ping -c 1 github.com >/dev/null 2>&1
			return $?
		}
		if check_internet; then
			echo "Downloading from $CAVE_URL" >>"$LOGPATH"
			wget -O "$BIOS_FOLDER$CZ_NAME" "$CAVE_URL"
		else
			# If local copy doesn't exist and cannot download a copy, pop message
			echo "Unable to download $CZ_NAME" >>"$LOGPATH"
			TITLE="Missing File"
			CONTENT="Cave Story (En).zip not found in /MUOS/bios
			Please see https://muos.dev for more information!"
			MESSAGE "$TITLE" "$CONTENT" 5
		fi
	fi

	## Extract the zip
	echo "Extracting $CZ_NAME to $F_PATH" >>"$LOGPATH"
	unzip -o "$BIOS_FOLDER$CZ_NAME" -d "$F_PATH"

	if [ -e "$F_PATH/Cave Story (En)" ]; then
		echo "Hiding folder" >>"$LOGPATH"
		mv "$F_PATH/Cave Story (En)" "$F_PATH/.Cave Story (En)"
	elif [ -e "$F_PATH/.Cave Story (En)" ]; then
		echo "Already hidden" >>"$LOGPATH"
	else
		echo "Did extraction fail?" >>"$LOGPATH"
	fi

	retroarch -v -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$DOUK" &
	RA_PID=$!
fi

wait $RA_PID
unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
