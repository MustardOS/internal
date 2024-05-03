#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <archive>"
	exit 1
fi

if [ ! -e "$1" ]; then
	echo "Error: Archive '$1' not found"
	exit 1
fi

pkill -STOP muxarchive

echo " " > /tmp/muxlog_msg
/opt/muos/extra/muxlog &

ARCHIVE_NAME="${1##*/}"
MUX_TEMP="/opt/muxtmp"

rm -rf "$MUX_TEMP"
mkdir "$MUX_TEMP"

TMP_FILE=$(mktemp)

push_to_muxlog() {
	current_line=""
	while true; do
		if [ -s "$TMP_FILE" ]; then
			new_line=$(tail -n 1 "$TMP_FILE" | sed 's/^[[:space:]]*//')
			if [ "$new_line" != "$current_line" ]; then
				echo "$new_line" > /tmp/muxlog_info
				current_line="$new_line"
			fi
		fi
	done
}
push_to_muxlog &

echo "Extracting Archive" > /tmp/muxlog_msg
unzip -o "$1" -d "$MUX_TEMP/" > "$TMP_FILE" 2>&1 &
wait $!

rm -rf /tmp/tmp.*

echo "Copying Files" > /tmp/muxlog_msg
echo " " > /tmp/muxlog_info
cp -rf "$MUX_TEMP"/* /

echo "Correcting Permissions" > /tmp/muxlog_msg
echo " " > /tmp/muxlog_info
chmod -R 755 /opt/muos

echo "Removing Temporary Storage" > /tmp/muxlog_msg
echo " " > /tmp/muxlog_info
rm -Rf "$MUX_TEMP"

UPDATE_SCRIPT=/opt/update.sh
if [ -s "$UPDATE_SCRIPT" ]; then
	echo "Running Script" > /tmp/muxlog_msg
	echo " " > /tmp/muxlog_info
	chmod 755 "$UPDATE_SCRIPT"
	./"$UPDATE_SCRIPT"
	rm "$UPDATE_SCRIPT"
fi

touch "/mnt/mmc/MUOS/update/installed/$ARCHIVE_NAME.done"

echo "Filesystem Sync" > /tmp/muxlog_msg
echo " " > /tmp/muxlog_info
sync

echo "All done!" > /tmp/muxlog_msg
echo " " > /tmp/muxlog_info
sleep 1

echo "!end" > /tmp/muxlog_info

pkill -CONT muxarchive
pkill -f extract.sh

