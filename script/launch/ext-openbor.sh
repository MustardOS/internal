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

# Our OpenBOR builds hardcode Batocera /userdata paths. :( For example:
# https://github.com/batocera-linux/batocera.linux/blob/master/package/batocera/emulators/openbor/openbor7530/002-adjust-paths.patch
# https://github.com/batocera-linux/batocera.linux/blob/master/package/batocera/emulators/openbor/openbor7530/004-parsable-config-keys.patch
#
# The patches try to make the savesDir configurable, but this doesn't actually
# work consistently. Create a temporary /userdata symlink to work around this.
U_DATA="/userdata"

[ -d "$U_DATA" ] && rm -rf "$U_DATA"
ln -s "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/openbor/userdata" "$U_DATA"

if [ "$CORE" = "ext-openbor4432" ]; then
	BOR_BIN="OpenBOR4432"
elif [ "$CORE" = "ext-openbor6412" ]; then
	BOR_BIN="OpenBOR6412"
elif [ "$CORE" = "ext-openbor7142" ]; then
	BOR_BIN="OpenBOR7142"
elif [ "$CORE" = "ext-openbor7530" ]; then
	BOR_BIN="OpenBOR7530"
fi

SET_VAR "system" "foreground_process" "$BOR_BIN"

EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/openbor"

chmod +x "$EMUDIR"/"$BOR_BIN"
cd "$EMUDIR" || exit 1

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./"$BOR_BIN" "$FILE"

# Clean up /userdata symlink when we're done since it's such a generic path.
[ -d "$U_DATA" ] && rm -rf "$U_DATA"

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
