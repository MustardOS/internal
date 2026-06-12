#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)

LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/nxengine.log"

printf "Starting Cave Story (libretro)\n" >"$LOGPATH"
DOUK_BIOS="$MUOS_STORE_DIR/bios/nxengine/Doukutsu.exe"

CHECK_INTERNET() {
	printf "Pinging github.com\n" >>"$LOGPATH"
	ping -c 1 github.com >/dev/null 2>&1
}

GREENLIGHT=0

if [ -e "$DOUK_BIOS" ]; then
	printf "Doukutsu.exe found!\n" >>"$LOGPATH"
	GREENLIGHT=1
else
	printf "Doukutsu.exe NOT found!\n" >>"$LOGPATH"

	CZ_NAME="Cave Story (En).zip"
	CAVE_URL="https://bot.libretro.com/assets/cores/Cave Story/$CZ_NAME"
	printf "Cave Story URL: %s\n" "$CAVE_URL" >>"$LOGPATH"

	BIOS_FOLDER="$MUOS_STORE_DIR/bios/"
	printf "%s not found in %s\n" "$DOUK_BIOS" "$BIOS_FOLDER"

	if CHECK_INTERNET; then
		printf "Downloading from %s\n" "$CAVE_URL" >>"$LOGPATH"
		wget -O "$BIOS_FOLDER$CZ_NAME" "$CAVE_URL"

		printf "Extracting %s to %s/Cave Story (En)\n" "$CZ_NAME" "$BIOS_FOLDER" >>"$LOGPATH"
		unzip -o "$BIOS_FOLDER$CZ_NAME" -d "$BIOS_FOLDER"

		if [ -e "$BIOS_FOLDER/Cave Story (En)" ]; then
			printf "Renaming Cave Story (En) Folder to nxengine\n" >>"$LOGPATH"
			mv "$BIOS_FOLDER/Cave Story (En)" "$BIOS_FOLDER/nxengine"

			printf "Removing %s\n" "$CZ_NAME" >>"$LOGPATH"
			rm -f "$BIOS_FOLDER$CZ_NAME"

			GREENLIGHT=1
		elif [ -e "$BIOS_FOLDER/nxengine" ]; then
			printf "Already renamed\n" >>"$LOGPATH"
			GREENLIGHT=1
		else
			printf "Did extraction fail?\n" >>"$LOGPATH"
		fi
	else
		printf "Unable to download %s\n" "$CZ_NAME" >>"$LOGPATH"
	fi
fi

if [ "$GREENLIGHT" -eq 1 ]; then
	IS_SWAP=$(DETECT_CONTROL_SWAP)

	printf "Launching Cave Story\n" >>"$LOGPATH"

	set -- -v -f
	[ -n "$RA_ARGS" ] && set -- "$@" "$RA_ARGS"
	retroarch "$@" -L "$MUOS_SHARE_DIR/core/nxengine_libretro.so" "$DOUK_BIOS"

	[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
fi
