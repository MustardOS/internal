#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <archive>"
	exit 1
fi

if [ ! -e "$1" ]; then
	echo "Error: Archive '$1' not found"
	exit 1
fi

# Suspend the muxarchive program
pkill -STOP muxarchive

# Start the muxlog program
/opt/muos/extra/muxlog &

ARCHIVE_NAME="${1##*/}"
MUX_TEMP="/opt/muxtmp"

rm -rf $MUX_TEMP
mkdir $MUX_TEMP

# Function to push messages to muxlog
push_to_muxlog() {
	while read -r line; do
		echo "$line" > /tmp/muxlog
	done
}

unzip -o "$1" -d "$MUX_TEMP/" 2>&1 | push_to_muxlog &

# Wait for unzip to finish
wait $!

echo "Copying Files" > /tmp/muxlog
cp -rf $MUX_TEMP/* /

echo "Correcting Permissions" > /tmp/muxlog
chmod -R 755 /opt/muos

echo "Removing Temporary Storage" > /tmp/muxlog
rm -Rf $MUX_TEMP

UPDATE_SCRIPT=/opt/update.sh
if [ -s "$UPDATE_SCRIPT" ]; then
        echo "Running Script"
        chmod 755 "$UPDATE_SCRIPT"
        ."$UPDATE_SCRIPT"
        rm "$UPDATE_SCRIPT"
fi

touch "/mnt/mmc/MUOS/update/installed/$ARCHIVE_NAME.done"

echo "Filesystem Sync" > /tmp/muxlog
sync
sleep 5

echo "All done!" > /tmp/muxlog
sleep 1

echo "!end" > /tmp/muxlog

# Resume the muxbackup program
pkill -CONT muxarchive

