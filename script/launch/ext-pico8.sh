#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

_BACKUPFAV=$(cat <<EOF
#!/bin/sh 

P8_DIR="/mnt/mmc/MUOS/emulator/pico8/.lexaloffle/pico-8"
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

EMUDIR="/mnt/mmc/MUOS/emulator/pico8"

chmod +x $EMUDIR/wget
chmod +x $EMUDIR/pico8_64

cd $EMUDIR || continue

if [ "$NAME" = Splore ]; then
	PATH="$EMUDIR:$PATH" HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./pico8_64 -windowed 0 -splore
elif [ "$NAME" = BackupFaves ]; then
	/opt/muos/script/mux/track.sh "$NAME" \""/$ROM"\"
else
	PATH="$EMUDIR:$PATH" HOME="$EMUDIR" SDL_ASSERT=always_ignore nice --20 ./pico8_64 -windowed 0 -run "$ROM"
fi

