#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")
SDL_SCALER=$(parse_ini "$DEVICE_CONFIG" "sdl" "scaler")

NAME=$1
CORE=$2
ROM=$3

export HOME=/root
export SDL_HQ_SCALER="$SDL_SCALER"

echo "pico8_64" > /tmp/fg_proc

_BACKUPFAV=$(cat <<EOF
#!/bin/sh 

P8_DIR="/$STORE_ROM/MUOS/emulator/pico8/.lexaloffle/pico-8"
FAVES="$P8_DIR/favourites.txt"
CARTS="$P8_DIR/bbs/carts"

DEST=$(dirname "$0")

while IFS="|" read -r line
do
	filename=$(echo "$line" | cut -d'|' -f2)
	displayname=$(echo "$line" | cut -d'|' -f7)
	trimmed_filename=$(echo "$filename" | xargs)
	tidy_display=$(echo "$displayname" | xargs)
	cp $CARTS/$trimmed_filename.p8.png "$DEST/$tidy_display.p8.png"
done < "$FAVES"
EOF
	) > "$R_DIR"/"Backup Favourites.sh"

EMUDIR="/$STORE_ROM/MUOS/emulator/pico8"

chmod +x "$EMUDIR"/wget
chmod +x "$EMUDIR"/pico8_64

cd "$EMUDIR" || exit

if [ "$NAME" = "Splore" ]; then
	PATH="$EMUDIR:$PATH" HOME="$EMUDIR" SDL_ASSERT=always_ignore ./pico8_64 -windowed 0 -splore
elif [ "$NAME" = "Backup Favourites" ]; then
	./"$ROM"
else
	PATH="$EMUDIR:$PATH" HOME="$EMUDIR" SDL_ASSERT=always_ignore ./pico8_64 -windowed 0 -run "$ROM"
fi

