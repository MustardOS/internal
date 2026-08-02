#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "muxretro"

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

F_PATH=$(dirname "$FILE")

WOLF_RUNNER="$F_PATH/$NAME.wolf"

# Compensate for Windows wild cuntery
dos2unix -n "$WOLF_RUNNER" "$WOLF_RUNNER"

REAL_WOLF_EXE="$F_PATH/.$NAME/$(cat "$WOLF_RUNNER")"
FAKE_WOLF_EXE="$F_PATH/.$NAME/$(basename "$NAME").EXE"

# We do this so that save states are not mixed...
cp "$REAL_WOLF_EXE" "$FAKE_WOLF_EXE"

/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/ecwolf_libretro.so" "$FAKE_WOLF_EXE" $FRESH_ARG

rm -f "$FAKE_WOLF_EXE"
