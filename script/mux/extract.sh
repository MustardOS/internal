#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <archive>"
    exit 1
fi

if [ ! -e "$1" ]; then
    echo "Error: Archive '$1' not found"
    exit 1
fi

ARCHIVE_NAME="${1##*/}"
MUX_TEMP="/tmp/muxtmp"

mkdir $MUX_TEMP
unzip -o "$1" -d "$MUX_TEMP/"
cp -rf $MUX_TEMP/* /
chmod -R 755 /opt/muos
rm -Rf $MUX_TEMP

UPDATE_SCRIPT=/opt/update.sh
if [ -s "$UPDATE_SCRIPT" ]; then
	chmod 755 "$UPDATE_SCRIPT"
	."$UPDATE_SCRIPT"
	rm "$UPDATE_SCRIPT"
fi

touch "/mnt/mmc/MUOS/update/installed/$ARCHIVE_NAME.done"

sync

