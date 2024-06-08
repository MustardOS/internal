#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <archive>"
	exit 1
fi

if [ ! -e "$1" ]; then
	echo "Error: Archive '$1' not found"
	exit 1
fi

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

pkill -STOP muxarchive

/opt/muos/extra/muxlog &
sleep 0.5

echo "Waiting..." > /tmp/muxlog_info
sleep 0.5

ARCHIVE_NAME="${1##*/}"

TMP_FILE=/tmp/muxlog_global
rm -rf "$TMP_FILE"

MUX_TEMP="/opt/muxtmp"
mkdir "$MUX_TEMP"

# Check if archive is an Installable theme
SCHEME_FOLDER="scheme"
SCHEME_FILE="default.txt"
echo "Inspecting archive..." > /tmp/muxlog_info
if unzip -l "$1" | awk '$NF ~ /^'"$SCHEME_FOLDER"'\// && $NF ~ /\/'"$SCHEME_FILE"'$/ {print $NF}' | grep -q ""; then
	echo "Archive contents indicate it is NOT an installable theme file." > /tmp/muxlog_info
    echo "Copying unextracted archive to theme folder." > /tmp/muxlog_info
	cp -f "$1" "$STORE_ROM/MUOS/theme/"
else
	unzip -o "$1" -d "$MUX_TEMP/" > "$TMP_FILE" 2>&1 &

	C_LINE=""
	while true; do
		IS_WORKING=$(pgrep -f "unzip")

		if [ -s "$TMP_FILE" ]; then
			N_LINE=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
			if [ "$N_LINE" != "$C_LINE" ]; then
				echo "$N_LINE"
				echo "$N_LINE" > /tmp/muxlog_info
				C_LINE="$N_LINE"
			fi
		fi

		if [ -z "$IS_WORKING" ]; then
			break
		fi
		
		sleep 0.25
	done

	echo "Moving Files" > /tmp/muxlog_info
	find "$MUX_TEMP" -mindepth 1 -type f -exec sh -c '
		for SOURCE; do
			DIR_NAME=$(dirname "$SOURCE")
			DEST="${DIR_NAME#'"$MUX_TEMP"'}"
			echo "Moving $SOURCE to $DEST"
			mkdir -p "$DEST" && mv "$SOURCE" "$DEST"
		done
	' sh {} +
fi

echo "Correcting Permissions" > /tmp/muxlog_info
chmod -R 755 /opt/muos

UPDATE_SCRIPT=/opt/update.sh
if [ -s "$UPDATE_SCRIPT" ]; then
	echo "Running Update Script" > /tmp/muxlog_info
	chmod 755 "$UPDATE_SCRIPT"
	${UPDATE_SCRIPT}
	rm "$UPDATE_SCRIPT"
fi

echo "Sync Filesystem" > /tmp/muxlog_info
sync

echo "All Done!" > /tmp/muxlog_info
touch "$STORE_ROM/MUOS/update/installed/$ARCHIVE_NAME.done"
sleep 0.5

killall -q muxlog
rm -rf "$MUX_TEMP" /tmp/muxlog_*

pkill -CONT muxarchive
killall -q extract.sh

