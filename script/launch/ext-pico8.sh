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

SET_VAR "system" "foreground_process" "pico8_64"

GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"
EMUDIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/pico8"
CTRL_TYPE="$(GET_VAR "global" "settings/advanced/swap")"

# Set appropriate sdl controller file
if [ "$CTRL_TYPE" = 0 ]; then
	SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/opt/muos/device/current/control/gamecontrollerdb_modern.txt")
else
	SDL_GAMECONTROLLERCONFIG=$(grep "Deeplay" "/opt/muos/device/current/control/gamecontrollerdb_retro.txt")
fi
export SDL_GAMECONTROLLERCONFIG

# First look for emulator in BIOS directory, which allows it to follow the
# user's storage preference. Fall back on the old path for compatibility.
EMU="/run/muos/storage/bios/pico8/pico8_64"
if [ ! -f "$EMU" ]; then
	EMU="$EMUDIR/pico8_64"
fi

# Did the user select standard or Pixel Perfect scaler?
if [ "$CORE" = "ext-pico8-scale" ]; then
	PICO_FLAGS="-windowed 0"
elif [ "$CORE" = "ext-pico8-pixel" ]; then
	PICO_FLAGS="-windowed 0 -pixel_perfect 1"
fi

chmod +x "$EMUDIR"/wget
chmod +x "$EMU"

cd "$EMUDIR" || exit
ROMDIR="$(dirname "$ROM")"

if [ "$NAME" = "Splore" ]; then
	SDL_ASSERT=always_ignore \
		$GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
	PATH="$EMUDIR:$PATH" \
		HOME="$EMUDIR" \
		"$EMU" $PICO_FLAGS -root_path "$ROMDIR" -splore
else
	SDL_ASSERT=always_ignore \
		$GPTOKEYB "./pico8_64" -c "./pico8.gptk" &
	PATH="$EMUDIR:$PATH" \
		HOME="$EMUDIR" \
		"$EMU" $PICO_FLAGS -root_path "$ROMDIR" -run "$ROM"
fi

kill -9 "$(pidof pico8_64)" "$(pidof gptokeyb2)"

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

# SAVE THE FAVOURITES CHARLIE!
SD1="$(GET_VAR "device" "storage/rom/mount")/ROMS"
SD2="$(GET_VAR "device" "storage/sdcard/mount")/ROMS"
USB="$(GET_VAR "device" "storage/usb/mount")/ROMS"

P8_DIR=$(sed -n '2p' /run/muos/storage/info/core/pico-8/core.cfg)
for DIR in "$USB" "$SD2" "$SD1"; do
	[ -d "$DIR/$P8_DIR" ] && STORAGE_DIR="$DIR/$P8_DIR" && break
done
[ -z "$STORAGE_DIR" ] && exit 1

FAVOURITE="/run/muos/storage/save/pico8/favourites.txt"
CART_DIR="/run/muos/storage/save/pico8/bbs/carts"
BOXART_DIR="/run/muos/storage/info/catalogue/PICO-8/box"

# TODO: Work out what these other fields mean?! (maybe useful?)
while IFS='|' read -r _ RAW_NAME _ _ _ GOOD_NAME; do
	[ -z "$GOOD_NAME" ] || [ -z "$RAW_NAME" ] && continue
	RAW_NAME=$(echo "$RAW_NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\+//g')
	GOOD_NAME=$(echo "$GOOD_NAME" | sed -E 's/.*\|//;s/^[[:space:]]+|[[:space:]]+$//;s/\b(.)/\u\1/g')

	P8_EXT="p8.png"
	FAV_FILE="$CART_DIR/$RAW_NAME.$P8_EXT"
	DEST_FILE="$STORAGE_DIR/$GOOD_NAME.$P8_EXT"
	BOXART_FILE="$BOXART_DIR/$GOOD_NAME.$P8_EXT"

	[ ! -f "$FAV_FILE" ] && FAV_FILE="$CART_DIR/${RAW_NAME%${RAW_NAME#?}}/$RAW_NAME.$P8_EXT"
	if [ -f "$FAV_FILE" ]; then
		[ ! -f "$DEST_FILE" ] && cp "$FAV_FILE" "$DEST_FILE"
		[ ! -f "$BOXART_FILE" ] && cp "$FAV_FILE" "$BOXART_FILE"
	fi
done <"$FAVOURITE"
