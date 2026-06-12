#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

F_PATH=$(dirname "$FILE")

WOLF_RUNNER="$F_PATH/$NAME.wolf"

# Compensate for Windows wild cuntery
dos2unix -n "$WOLF_RUNNER" "$WOLF_RUNNER"

REAL_WOLF_EXE="$F_PATH/.$NAME/$(cat "$WOLF_RUNNER")"
FAKE_WOLF_EXE="$F_PATH/.$NAME/$(basename "$NAME").EXE"

# We do this so that save states are not mixed...
cp "$REAL_WOLF_EXE" "$FAKE_WOLF_EXE"

set -- -v -f
[ -n "$RA_ARGS" ] && set -- "$@" "$RA_ARGS"
retroarch "$@" -L "$MUOS_SHARE_DIR/core/ecwolf_libretro.so" "$FAKE_WOLF_EXE"

rm -f "$FAKE_WOLF_EXE"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
