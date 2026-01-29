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
IS_SWAP=$(DETECT_CONTROL_SWAP)

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')

WOLF_RUNNER="$F_PATH/$NAME.wolf"

# Compensate for Windows wild cuntery
dos2unix -n "$WOLF_RUNNER" "$WOLF_RUNNER"

REAL_WOLF_EXE="$F_PATH/.$NAME/$(cat "$WOLF_RUNNER")"
FAKE_WOLF_EXE="$F_PATH/.$NAME/$(basename "$NAME").EXE"

# We do this so that save states are not mixed...
cp "$REAL_WOLF_EXE" "$FAKE_WOLF_EXE"

retroarch -v -f $RA_ARGS -L "$MUOS_SHARE_DIR/core/ecwolf_libretro.so" "$FAKE_WOLF_EXE"

rm -f "$FAKE_WOLF_EXE"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
