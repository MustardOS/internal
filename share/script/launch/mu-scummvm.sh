#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "muxretro"

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

SUBFOLDER="$NAME"
F_PATH=$(dirname "$FILE")
[ -d "$F_PATH/.$NAME" ] && SUBFOLDER=".$NAME"

# The core wants the gameid file sitting beside the game data, not above it.
SCVM="$F_PATH/$SUBFOLDER/$NAME.scummvm"
cp "$F_PATH/$NAME.scummvm" "$SCVM"

/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/scummvm_libretro.so" "$SCVM" $FRESH_ARG
