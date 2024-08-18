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

. /opt/muos/script/var/device/storage.sh

. /opt/muos/script/var/global/storage.sh

ARCHIVE_NAME="${1##*/}"

SCHEME_FOLDER="scheme"
SCHEME_FILE="default.txt"
echo "Inspecting archive..."

if unzip -l "$1" | awk '$NF ~ /^'"$SCHEME_FOLDER"'\// && $NF ~ /\/'"$SCHEME_FILE"'$/ {print $NF}' | grep -q ""; then
	echo "Archive contents indicate it is NOT an installable theme file"
	echo "Copying unextracted archive to theme folder"
	cp -f "$1" "$GC_STO_THEME/MUOS/theme/"
else
	MUX_TEMP="/opt/muxtmp"
	mkdir "$MUX_TEMP"
 	MNT_TEMP="/opt/mnttmp"
  	mkdir "$MNT_TEMP"
	unzip -o "$1" -d "$MUX_TEMP/" 
 
 	if [ -d "$MUX_TEMP/mnt/" ]; then
  	mv "$MUX_TEMP/mnt" "$MNT_TEMP/mnt"
   	fi

	echo "Moving Files"
	find "$MUX_TEMP" -mindepth 1 -type f -exec sh -c '
		for SOURCE; do
			DIR_NAME=$(dirname "$SOURCE")
			DEST="${DIR_NAME#'"$MUX_TEMP"'}"
			echo "Moving $SOURCE to $DEST"
			mkdir -p "$DEST" && mv "$SOURCE" "$DEST"
		done
	' sh {} +

 	if [ -d "$MNT_TEMP/mnt/mmc/MUOS/bios/" ]; then
    	echo "Copying BIOS folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/bios" "$GC_STO_BIOS/MUOS/bios"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/bios/" ]; then
    	echo "Copying BIOS folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/bios" "$GC_STO_BIOS/MUOS/bios"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/bios/" ]; then
    	echo "Copying BIOS folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/bios" "$GC_STO_BIOS/MUOS/bios"
  	fi

    	if [ -d "$MNT_TEMP/mnt/mmc/MUOS/theme/" ]; then
    	echo "Copying theme folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/theme" "$GC_STO_THEME/MUOS/theme"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/theme/" ]; then
    	echo "Copying theme folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/theme" "$GC_STO_THEME/MUOS/theme"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/theme/" ]; then
    	echo "Copying theme folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/theme" "$GC_STO_THEME/MUOS/theme"
  	fi

       	if [ -d "$MNT_TEMP/mnt/mmc/MUOS/music/" ]; then
    	echo "Copying music folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/music" "$GC_STO_MUSIC/MUOS/music"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/music/" ]; then
    	echo "Copying music folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/music" "$GC_STO_MUSIC/MUOS/music"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/music/" ]; then
    	echo "Copying music folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/music" "$GC_STO_MUSIC/MUOS/music"
  	fi

   	if [ -d "$MNT_TEMP/mnt/mmc/MUOS/screenshot/" ]; then
    	echo "Copying screenshot folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/screenshot" "$GC_STO_SCREENSHOT/MUOS/screenshot"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/screenshot/" ]; then
    	echo "Copying screenshot folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/screenshot" "$GC_STO_SCREENSHOT/MUOS/screenshot"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/screenshot/" ]; then
    	echo "Copying screenshot folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/screenshot" "$GC_STO_SCREENSHOT/MUOS/screenshot"
  	fi

      	if [ -d "$MNT_TEMP/mnt/mmc/MUOS/save/" ]; then
    	echo "Copying save folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/save" "$GC_STO_SAVE/MUOS/save"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/save/" ]; then
    	echo "Copying save folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/save" "$GC_STO_SAVE/MUOS/save"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/save/" ]; then
    	echo "Copying save folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/save" "$GC_STO_SAVE/MUOS/save"
  	fi

        if [ -d "$MNT_TEMP/mnt/mmc/MUOS/info/catalogue/" ]; then
    	echo "Copying catalogue folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/info/catalogue" "$GC_STO_CATALOGUE/MUOS/info/catalogue"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/info/catalogue/" ]; then
    	echo "Copying catalogue folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/info/catalogue" "$GC_STO_CATALOGUE/MUOS/info/catalogue"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/info/catalogue/" ]; then
    	echo "Copying catalogue folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/info/catalogue" "$GC_STO_CATALOGUE/MUOS/info/catalogue"
  	fi

        if [ -d "$MNT_TEMP/mnt/mmc/MUOS/info/config/" ]; then
    	echo "Copying config folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/info/config" "$GC_STO_CONFIG/MUOS/info/config"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/info/config/" ]; then
    	echo "Copying config folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/info/config" "$GC_STO_CONFIG/MUOS/info/config"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/info/config/" ]; then
    	echo "Copying config folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/info/config" "$GC_STO_CONFIG/MUOS/info/config"
  	fi

        if [ -d "$MNT_TEMP/mnt/mmc/MUOS/info/favourite/" ]; then
    	echo "Copying favourite folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/info/favourite" "$GC_STO_FAV/MUOS/info/favourite"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/info/favourite/" ]; then
    	echo "Copying favourite folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/info/favourite" "$GC_STO_FAV/MUOS/info/favourite"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/info/favourite/" ]; then
    	echo "Copying favourite folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/info/favourite" "$GC_STO_FAV/MUOS/info/favourite"
  	fi

        if [ -d "$MNT_TEMP/mnt/mmc/MUOS/info/activity/" ]; then
    	echo "Copying activity folder..."
     	mv "$MNT_TEMP/mnt/mmc/MUOS/info/activity" "$GC_STO_FAV/MUOS/info/activity"
  	fi

    	if [ -d "$MNT_TEMP/mnt/sdcard/MUOS/info/activity/" ]; then
    	echo "Copying activity folder..."
     	mv "$MNT_TEMP/mnt/sdcard/MUOS/info/activity" "$GC_STO_FAV/MUOS/info/activity"
  	fi

       	if [ -d "$MNT_TEMP/mnt/usb/MUOS/info/activity/" ]; then
    	echo "Copying activity folder..."
     	mv "$MNT_TEMP/mnt/usb/MUOS/info/activity" "$GC_STO_FAV/MUOS/info/activity"
  	fi

   	echo "Moving Files"
	find "$MNT_TEMP" -mindepth 1 -type f -exec sh -c '
		for SOURCE; do
			DIR_NAME=$(dirname "$SOURCE")
			DEST="${DIR_NAME#'"$MNT_TEMP"'}"
			echo "Moving $SOURCE to $DEST"
			mkdir -p "$DEST" && mv "$SOURCE" "$DEST"
		done
	' sh {} +
   
	rm -rf "$MUX_TEMP"
 	rm -rf "$MNT_TEMP"
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

/opt/muos/script/mux/sync_storage.sh theme &

echo "All Done!"
touch "$DC_STO_ROM_MOUNT/MUOS/update/installed/$ARCHIVE_NAME.done"
sleep 2

pkill -CONT muxarchive
exit 0
