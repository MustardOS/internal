#!/bin/sh

pkill -STOP muxarchive

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <archive>"
	sleep 2
	
	pkill -CONT muxarchive
	exit 1
fi

if [ ! -e "$1" ]; then
	echo "Error: Archive '$1' not found"
	sleep 2
	
	pkill -CONT muxarchive
	exit 1
fi

. /opt/muos/script/var/func.sh

ARCHIVE_NAME="${1##*/}"

SCHEME_FOLDER="scheme"
SCHEME_FILE="default.txt"
echo "Inspecting archive..."

if unzip -l "$1" | awk '$NF ~ /^'"$SCHEME_FOLDER"'\// && $NF ~ /\/'"$SCHEME_FILE"'$/ {print $NF}' | grep -q ""; then
	echo "Archive contents indicate it is NOT an installable theme file"
	echo "Copying unextracted archive to theme folder"
	cp -f "$1" "/run/muos/storage/theme/"
else
	MUX_TEMP="/opt/muxtmp"
	mkdir "$MUX_TEMP"
	unzip -o "$1" -d "$MUX_TEMP/" 

	echo "Moving Files"
	find "$MUX_TEMP" -mindepth 1 -type f -exec sh -c '
		for SOURCE; do
			DIR_NAME=$(dirname "$SOURCE")
			DEST="${DIR_NAME#'"$MUX_TEMP"'}"
			echo "Moving $SOURCE to $DEST"
			mkdir -p "$DEST" && mv "$SOURCE" "$DEST"
		done
	' sh {} +
	
	rm -rf "$MUX_TEMP"
fi

echo "Correcting Permissions"
chmod -R 755 /opt/muos

UPDATE_SCRIPT=/opt/update.sh
if [ -s "$UPDATE_SCRIPT" ]; then
	echo "Running Update Script"
	chmod 755 "$UPDATE_SCRIPT"
	${UPDATE_SCRIPT}
	rm "$UPDATE_SCRIPT"
fi

echo "Sync Filesystem"
sync

echo "All Done!"
touch "$(GET_VAR "device" "storage/rom/mount")/MUOS/update/installed/$ARCHIVE_NAME.done"
sleep 2

pkill -CONT muxarchive
exit 0
