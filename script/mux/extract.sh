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
	FILE_COUNT="$(unzip -Z1 "$1" | grep -cv '/$')"
	MUX_TEMP="/opt/muxtmp"
	mkdir "$MUX_TEMP"

	echo "Extracting files..."
	unzip -o "$1" -d "$MUX_TEMP/" \
		| grep --line-buffered -E '^ *(extracting|inflating):' | /opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

	echo "Moving files..."
	rsync --archive --ignore-times --remove-source-files --itemize-changes --outbuf=L "$MUX_TEMP/" / \
		| grep --line-buffered '^>f' | /opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

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
