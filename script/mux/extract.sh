#!/bin/sh

sync_folder() {
    source="$1"
    dest="$2"
	# Sync the current folder to the determined destination
	echo "Syncing ${source##*/} to $dest..."
	rsync --archive --ignore-times --remove-source-files --itemize-changes --outbuf=L "$source/" "$dest/" |
		grep --line-buffered '^>f' |
		/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null
}

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

if [[ "$ARCHIVE_NAME" == *.muxthm ]]; then
	echo "Copying unextracted archive to theme folder"
	cp -f "$1" "/run/muos/storage/theme/"
elif [[ "$ARCHIVE_NAME" == *.muxcat ]]; then
	echo "Copying unextracted archive to package/catalogue folder"
	cp -f "$1" "/run/muos/storage/package/catalogue/"
elif [[ "$ARCHIVE_NAME" == *.muxcfg ]]; then
	echo "Copying unextracted archive to package/config folder"
	cp -f "$1" "/run/muos/storage/package/config/"
elif unzip -l "$1" | awk '$NF ~ /^pico-8\// {folders[$NF]=1} $NF ~ /^pico-8\/(pico8_64|pico8\.dat)$/ {files[$NF]=1} END {if ("pico-8/" in folders && "pico-8/pico8_64" in files && "pico-8/pico8.dat" in files) exit 0; else exit 1}'; then
    echo "Archive contains a valid pico-8 folder with required files"
    
	BIOS_DIR="/run/muos/storage/bios/"
	if unzip -j "$1" "pico-8/*" -d "${BIOS_DIR}pico-8/"; then
        echo "Extracted 'pico-8' folder to $BIOS_DIR"
    else
        echo "Failed to extract 'pico-8' folder"
        exit 1
    fi
else
	# Count total files in archive to show progress bar for unzip and rsync.
	# Not as precise as monitoring bytes decompressed, but much easier, and
	# still gives a high-level indication how far along the process is.
	FILE_COUNT="$(unzip -Z1 "$1" | grep -cv '/$')"

	MUX_TEMP="/opt/muxtmp"
	mkdir "$MUX_TEMP"

	echo "Extracting files..."
	unzip -o "$1" -d "$MUX_TEMP/" |
		grep --line-buffered -E '^ *(extracting|inflating):' |
		/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

	case "$ARCHIVE_NAME" in
		*.muxapp) 
			echo "Extracting Application archive..."
			sync_folder "$MUX_TEMP" "/mnt/mmc/MUOS/application"
			;;
		*)
			echo "Processing and moving files..."
			for folder in "$MUX_TEMP"/*; do
				if [ -d "$folder" ]; then
					folder_name=$(basename "$folder")
					echo "Processing folder: $folder_name"

					# Define destination directory based on folder name
					case "$folder_name" in
						catalogue)
							DESTINATION="/run/muos/storage/info/catalogue"
							;;
						info)
							DESTINATION="/run/muos/storage/info"
							;;
						muos)
							DESTINATION="/run/muos/storage"
							;;
						bios)
							DESTINATION="/run/muos/storage/bios"
							;;
						language)
							DESTINATION="/run/muos/storage/language"
							;;
						theme)
							DESTINATION="/run/muos/storage/theme"
							;;
						*)
							DESTINATION="/$folder_name"
							;;
					esac
					
					sync_folder "$folder" "$DESTINATION"
				fi
			done
			;;
	esac

	# Clean up temporary directory
	rm -rf "$MUX_TEMP"
fi

echo "Correcting permissions..."
chmod -R 755 /opt/muos

UPDATE_SCRIPT=/opt/update.sh
if [ -s "$UPDATE_SCRIPT" ]; then
	echo "Running update script..."
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
