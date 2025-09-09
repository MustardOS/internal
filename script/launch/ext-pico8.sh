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

P8_BIN="pico8_64"
SET_VAR "system" "foreground_process" "$P8_BIN"

EMUDIR="$MUOS_SHARE_DIR/emulator/pico8"

# First look for emulator in BIOS directory, which allows it to follow the
# user's storage preference. Fall back on the old path for compatibility.
# People often seem to copy the "pico-8" folder directly from their purchased files, so let's check for that.
EMU="$MUOS_STORE_DIR/bios/pico8/$P8_BIN"
if [ ! -f "$EMU" ]; then
	EMU="$MUOS_STORE_DIR/bios/pico-8/$P8_BIN"
	[ ! -f "$EMU" ] && EMU="$EMUDIR/$P8_BIN"
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

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

F_DIR="$(dirname "$FILE")"

GPTOKEYB="$MUOS_SHARE_DIR/emulator/gptokeyb/gptokeyb2"
$GPTOKEYB "./$P8_BIN" -c "./pico8.gptk" &

if [ "$NAME" = "Splore" ]; then
	PATH="$EMUDIR:$PATH" HOME="$EMUDIR" "$EMU" $PICO_FLAGS -root_path "$F_DIR" -splore
else
	PATH="$EMUDIR:$PATH" HOME="$EMUDIR" "$EMU" $PICO_FLAGS -root_path "$F_DIR" -run "$FILE"
fi

killall -9 "$(pidof $P8_BIN)" "$(pidof gptokeyb2)"

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

FAVOURITE="$MUOS_STORE_DIR/save/pico8/favourites.txt"
if [ -e "$FAVOURITE" ]; then
	# SAVE THE FAVOURITES CHARLIE!
	# Grab the PICO-8 ROM Folder
	STORAGE_DIR=${FILE%/*}

	CART_DIR="$MUOS_STORE_DIR/save/pico8/bbs"
	BOXART_DIR="$MUOS_STORE_DIR/info/catalogue/PICO-8/box"

	# TODO: Work out what these other fields mean?! (maybe useful?)
	while IFS='|' read -r _ RAW_NAME _ _ _ _ GOOD_NAME; do
		[ -z "$GOOD_NAME" ] || [ -z "$RAW_NAME" ] && continue
		RAW_NAME=$(echo "$RAW_NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\+//g')
		GOOD_NAME=$(echo "$GOOD_NAME" | sed -E 's/.*\|//;s/^[[:space:]]+|[[:space:]]+$//;s/\b(.)/\u\1/g' | tr -d ':')

		P8_SRC_EXT="p8.png"
		DEST_EXT="p8"
		PNG_EXT="png"

		FAV_FILE=""

		for DIR in "$CART_DIR" "$CART_DIR"/*; do
			DIR="${DIR%/}"
			if [ "$(basename "$DIR")" = "labels" ]; then
				continue
			fi
			if [ -f "$DIR/$RAW_NAME.$P8_SRC_EXT" ]; then
				FAV_FILE="$DIR/$RAW_NAME.$P8_SRC_EXT"
				break
			fi
		done

		if [ -n "$FAV_FILE" ]; then
			DEST_FILE="$STORAGE_DIR/$GOOD_NAME.$DEST_EXT"
			BOXART_FILE="$BOXART_DIR/$GOOD_NAME.$PNG_EXT"
			cp "$FAV_FILE" "$DEST_FILE"
			cp "$FAV_FILE" "$BOXART_FILE"
		fi
	done <"$FAVOURITE"
fi
