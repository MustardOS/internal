#!/bin/sh

SYNC_FOLDER() {
	SOURCE="$1"
	DEST="$2"
	echo "Syncing '${SOURCE##*/}' to '$DEST'..."
	rsync --archive --ignore-times --remove-source-files --itemize-changes --outbuf=L "$SOURCE/" "$DEST/" |
		grep --line-buffered '^>f' |
		/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null
}

ALL_DONE() {
	sleep 2
	pkill -CONT muxarchive
	exit "$1"
}

pkill -STOP muxarchive

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <archive>"
	ALL_DONE 1
fi

if [ ! -e "$1" ]; then
	echo "Error: ARCHIVE '$1' not found"
	ALL_DONE 1
fi

. /opt/muos/script/var/func.sh

ARCHIVE_NAME="${1##*/}"
echo "Inspecting Archive..."

case "$ARCHIVE_NAME" in
	pico-8_*)
		if unzip -l "$1" | awk '$NF ~ /^pico-8\// {FOLDERS[$NF]=1} $NF ~ /^pico-8\/(pico8_64|pico8\.dat)$/ {FILES[$NF]=1} END {if ("pico-8/" in FOLDERS && "pico-8/pico8_64" in FILES && "pico-8/pico8.dat" in FILES) exit 0; else exit 1}'; then
			echo "Archive contains a valid PICO-8 folder with required files"
			BIOS_DIR="/run/muos/storage/bios/"
			if unzip -j "$1" "pico-8/*" -d "${BIOS_DIR}pico-8/"; then
				echo "Extracted 'pico-8' Folder to '$BIOS_DIR'"
			else
				echo "Failed to Extract 'pico-8' Folder"
				ALL_DONE 1
			fi
		fi
		;;
	*.muxthm)
		echo "Moving Archive to THEME Folder"
		mv "$1" "/run/muos/storage/theme/"
		;;
	*.muxcat)
		echo "Moving Archive to PACKAGE/CATALOGUE Folder"
		mv "$1" "/run/muos/storage/package/catalogue/"
		;;
	*.muxcfg)
		echo "Moving archive to PACKAGE/CONFIG folder"
		mv "$1" "/run/muos/storage/package/config/"
		;;
	*.muxapp | *.muxupd | *.muxzip)
		# Count total files in ARCHIVE for progress tracking
		FILE_COUNT="$(unzip -Z1 "$1" | grep -cv '/$')"
		MUX_TEMP="/opt/muxtmp"
		mkdir "$MUX_TEMP"

		echo "Extracting Files..."
		unzip -o "$1" -d "$MUX_TEMP/" |
			grep --line-buffered -E '^ *(extracting|inflating):' |
			/opt/muos/bin/pv -pls "$FILE_COUNT" >/dev/null

		case "$ARCHIVE_NAME" in
			*.muxapp)
				echo "Extracting Application Archive..."
				SYNC_FOLDER "$MUX_TEMP" "$(GET_VAR "device" "storage/rom/mount")/MUOS/application"
				;;
			*)
				echo "Processing and Moving Files..."
				for FOLDER in "$MUX_TEMP"/*; do
					if [ -d "$FOLDER" ]; then
						FOLDER_NAME=$(basename "$FOLDER")
						echo "Processing Folder: $FOLDER_NAME"

						case "$FOLDER_NAME" in
							catalogue) DESTINATION="/run/muos/storage/info/catalogue" ;;
							info) DESTINATION="/run/muos/storage/info" ;;
							muos) DESTINATION="/run/muos/storage" ;;
							bios) DESTINATION="/run/muos/storage/bios" ;;
							language) DESTINATION="/run/muos/storage/language" ;;
							theme) DESTINATION="/run/muos/storage/theme" ;;
							*) DESTINATION="/$FOLDER_NAME" ;;
						esac

						SYNC_FOLDER "$FOLDER" "$DESTINATION"
					fi
				done
				;;
		esac

		rm -rf "$MUX_TEMP"
		;;
esac

echo "Correcting Permissions..."
chmod -R 755 /opt/muos

# Only allow update archives to run the update script!
case "$ARCHIVE_NAME" in
	*.muxupd)
		UPDATE_SCRIPT=/opt/update.sh
		if [ -s "$UPDATE_SCRIPT" ]; then
			echo "Running Update Script..."
			chmod 755 "$UPDATE_SCRIPT"
			"$UPDATE_SCRIPT"
			rm "$UPDATE_SCRIPT"
		fi
		;;
esac

touch "$(GET_VAR "device" "storage/rom/mount")/MUOS/update/installed/$ARCHIVE_NAME.done"

echo "Sync Filesystem"
sync

echo "All Done!"
ALL_DONE 0
