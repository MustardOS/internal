#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

LOG_INFO "$0" 0 "CONTENT LAUNCH" "NAME: %s\tCORE: %s\tROM: %s\n" "$NAME" "$CORE" "$ROM"

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
[ -L /userdata ] && rm /userdata
ln -s "$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/openbor/userdata" /userdata

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

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./"$BOR_BIN" "$ROM"

# Clean up /userdata symlink when we're done since it's such a generic path.
rm /userdata

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED
