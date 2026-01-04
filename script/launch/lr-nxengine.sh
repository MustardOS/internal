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

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/nxengine.log"

echo "Starting Cave Story (libretro)" >"$LOGPATH"
DOUK_BIOS="$MUOS_STORE_DIR/bios/nxengine/Doukutsu.exe"

if [ -e "$DOUK_BIOS" ]; then
	echo "Doukutsu.exe found!" >>"$LOGPATH"
	GREENLIGHT=1
else
	echo "Doukutsu.exe NOT found!" >>"$LOGPATH"

	CZ_NAME="Cave Story (En).zip"
	CAVE_URL="https://bot.libretro.com/assets/cores/Cave Story/$CZ_NAME"
	echo "Cave Story URL: $CAVE_URL" >>"$LOGPATH"

	BIOS_FOLDER="$MUOS_STORE_DIR/bios/"
	echo "$DOUK_BIOS not found in $BIOS_FOLDER"

	CHECK_INTERNET() {
		echo "Pinging github.com" >>"$LOGPATH"
		ping -c 1 github.com >/dev/null 2>&1
		return $?
	}

	if CHECK_INTERNET; then
		echo "Downloading from $CAVE_URL" >>"$LOGPATH"
		wget -O "$BIOS_FOLDER$CZ_NAME" "$CAVE_URL"

		echo "Extracting $CZ_NAME to $BIOS_FOLDER/Cave Story (En)" >>"$LOGPATH"
		unzip -o "$BIOS_FOLDER$CZ_NAME" -d "$BIOS_FOLDER"

		if [ -e "$BIOS_FOLDER/Cave Story (En)" ]; then
			echo "Renaming Cave Story (En) Folder to nxengine" >>"$LOGPATH"
			mv "$BIOS_FOLDER/Cave Story (En)" "$BIOS_FOLDER/nxengine"

			echo "Removing $CZ_NAME"
			rm -f "$BIOS_FOLDER$CZ_NAME"

			GREENLIGHT=1
		elif [ -e "$BIOS_FOLDER/nxengine" ]; then
			echo "Already renamed" >>"$LOGPATH"
			GREENLIGHT=1
		else
			echo "Did extraction fail?" >>"$LOGPATH"
		fi
	else
		echo "Unable to download $CZ_NAME" >>"$LOGPATH"
		GREENLIGHT=0
	fi
fi

if [ "$GREENLIGHT" -eq 1 ]; then
	IS_SWAP=$(DETECT_CONTROL_SWAP)

	echo "Launching Cave Story" >>"$LOGPATH"

	LD_PRELOAD="/opt/muos/frontend/lib/libmustage.so" retroarch -v -f $RA_ARGS -L "$MUOS_SHARE_DIR/core/nxengine_libretro.so" "$DOUK"

	[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
fi
