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

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')

DOOM_RUNNER="$F_PATH/$NAME.doom"
WAD_DIR="$F_PATH/.WAD"

# Compensate for Windows wild cuntery
dos2unix -n "$DOOM_RUNNER" "$DOOM_RUNNER"

TARGET_DIR="$F_PATH/.$NAME"
mkdir -p "$TARGET_DIR"

COPY_DONE=0

RUN_FAILURE() {
	SHOW_MESSAGE 100 "Error Loading DOOM Content\n\n$1"

	MESSAGE stop
	sleep 3

	exit 1
}

CHECK_AND_COPY() {
	SRC="$1"
	DEST="$2"
	FILE="$3"
	PROG="$4"

	[ -z "$FILE" ] && return 0
	[ -f "$DEST/$FILE" ] && return 0
	[ ! -f "$SRC/$FILE" ] && return 1

	SHOW_MESSAGE "$PROG" "Loading DOOM Content\n\nCopying '$FILE'"
	cp -f "$SRC/$FILE" "$DEST/$FILE"

	COPY_DONE=1
	return 0
}

PWADS=""
DEHS=""
IWAD=""

while IFS='"' read -r key value _; do
	case "$key" in
		*parentwad*) IWAD="$value" ;;
		*wadfile_*) PWADS="$PWADS $value" ;;
		*dehfile_*) DEHS="$DEHS $value" ;;
	esac
done <"$DOOM_RUNNER"

[ -z "$IWAD" ] && RUN_FAILURE "Parent WAD not defined"

if ! CHECK_AND_COPY "$WAD_DIR" "$TARGET_DIR" "$IWAD" 25; then
	RUN_FAILURE "Required IWAD '$IWAD' not found"
fi

for FILE in $PWADS; do
	if ! CHECK_AND_COPY "$WAD_DIR" "$TARGET_DIR" "$FILE" 50; then
		RUN_FAILURE "Patch WAD '$FILE' not found"
	fi
done

for FILE in $DEHS; do
	if ! CHECK_AND_COPY "$WAD_DIR" "$TARGET_DIR" "$FILE" 75; then
		RUN_FAILURE "DeHackEd file '$FILE' not found"
	fi
done

[ $COPY_DONE -eq 1 ] && SHOW_MESSAGE 100 "Loading DOOM Content\n\nSuccess!" && sleep 0.5

MESSAGE stop

PRBC="$TARGET_DIR/prboom.cfg"
PRBW="$TARGET_DIR/${NAME}_prboom.wad"

cp -f "$DOOM_RUNNER" "$PRBC"
cp -f "$MUOS_STORE_DIR/bios/prboom.wad" "$PRBW"

retroarch -v -f $RA_ARGS -L "$MUOS_SHARE_DIR/core/prboom_libretro.so" "$PRBW"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
