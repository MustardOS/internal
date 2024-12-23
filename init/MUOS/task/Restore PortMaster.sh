#!/bin/sh
# HELP: Restore PortMaster application
# ICON: sdcard

. /opt/muos/script/var/func.sh

PM_ZIP="/opt/muos/PortMaster/muos.portmaster.zip"

if [ ! -e "$PM_ZIP" ]; then
	echo "Error: PortMaster archive not found!"
	sleep 2

	pkill -CONT muxtask
	exit 1
fi

# PortMaster Purge Time!
rm -rf /mnt/mmc/MUOS/Portmaster

FILE_COUNT="$(unzip -Z1 "$PM_ZIP" | grep -cv '/$')"

MUX_TEMP="/opt/muxtmp"
mkdir "$MUX_TEMP"

echo "Extracting files..."
unzip -o "$PM_ZIP" -d "$MUX_TEMP/" |
	grep --line-buffered -E '^ *(extracting|inflating):' |
	/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

echo "Moving files..."
rsync --archive --ignore-times --remove-source-files --itemize-changes --outbuf=L "$MUX_TEMP/" / |
	grep --line-buffered '^>f' |
	/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

rm -rf "$MUX_TEMP"

echo "Sync Filesystem"
sync

echo "All Done!"
sleep 2

pkill -CONT muxtask
exit 0
