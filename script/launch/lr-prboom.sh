#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
	LOG_INFO "$0" 0 "Content Launch" "DETAIL"
	LOG_INFO "$0" 0 "NAME" "$NAME"
	LOG_INFO "$0" 0 "CORE" "$CORE"
	LOG_INFO "$0" 0 "FILE" "$FILE"
) &

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
DOOM_RUNNER="$F_PATH/$NAME.doom"

# Compensate for Windows wild cuntery
dos2unix -n "$DOOM_RUNNER" "$DOOM_RUNNER"

TARGET_DIR="$F_PATH/.$NAME"
mkdir -p "$TARGET_DIR"

RUN_FAILURE() {
	printf "%s" "$1" >"/tmp/run_error"
	exit 1
}

CHECK_AND_COPY() {
	SRC="$1"
	DEST="$2"
	FILE="$3"

	[ -z "$FILE" ] && return 0
	[ -f "$DEST/$FILE" ] && return 0

	[ ! -f "$SRC/$FILE" ] && RUN_FAILURE "Required file '$FILE' not found."

	cp -f "$SRC/$FILE" "$DEST/$FILE"
}

PROCESS_EXTRA_FILES() {
	LIST="$1"
	FOLDER="$2"
	MSG="$3"

	for FILE in $LIST; do
		[ -z "$FILE" ] && continue
		[ -f "$TARGET_DIR/$FILE" ] && continue

		if [ -f "$F_PATH/$FOLDER/$FILE" ]; then
			CHECK_AND_COPY "$F_PATH/$FOLDER" "$TARGET_DIR" "$FILE"
		else
			RUN_FAILURE "$MSG '$FILE' not found."
		fi
	done
}

IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$DOOM_RUNNER")

[ -z "$IWAD" ] && RUN_FAILURE "Parent WAD not defined."

CHECK_AND_COPY "$F_PATH/.IWAD" "$TARGET_DIR" "$IWAD"

# For future reference PWADS and DEHS can coexist in the same directory!

PWADS=$(awk -F'"' '/wadfile_/ {print $2}' "$DOOM_RUNNER" | sed '/^$/d')
PROCESS_EXTRA_FILES "$PWADS" ".PWAD" "Patch WAD"

DEHS=$(awk -F'"' '/dehfile_/ {print $2}' "$DOOM_RUNNER" | sed '/^$/d')
PROCESS_EXTRA_FILES "$DEHS" ".DEHS" "DeHackEd file"

PRBC="$TARGET_DIR/prboom.cfg"
PRBW="$TARGET_DIR/${NAME}_prboom.wad"

cp -f "$DOOM_RUNNER" "$PRBC"
cp -f "$MUOS_STORE_DIR/bios/prboom.wad" "$PRBW"

nice --20 retroarch -v -f $RA_ARGS -L "$MUOS_SHARE_DIR/core/prboom_libretro.so" "$PRBW"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
