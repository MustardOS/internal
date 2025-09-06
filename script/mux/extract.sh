#!/bin/sh
set -eu

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

ALL_DONE() {
	printf "\nSync Filesystem\n"
	sync

	printf "All Done!\n"
	TBOX sleep 2
	FRONTEND start "${FRONTEND_START_PROGRAM:-archive}"

	exit "${1:-0}"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	printf "Usage: %s <archive> [mux module]\n" "$0"
	ALL_DONE 1
fi

ARCHIVE="$1"
[ -e "$ARCHIVE" ] || {
	printf "\nError: Archive '%s' not found\n" "$ARCHIVE"
	ALL_DONE 1
}

ARCHIVE_NAME="${ARCHIVE##*/}"
FRONTEND_START_PROGRAM="${2:-archive}"
printf "Inspecting Archive...\n"

case "$ARCHIVE_NAME" in
	pico-8_*)
		if unzip -l "$ARCHIVE" | awk '
			$NF ~ /^pico-8\// {FOLDERS[$NF]=1}
			$NF ~ /^pico-8\/(pico8_64|pico8\.dat)$/ {FILES[$NF]=1}
			END {
				if ("pico-8/" in FOLDERS && "pico-8/pico8_64" in FILES && "pico-8/pico8.dat" in FILES) exit 0; else exit 1
			}'; then
			printf "\nArchive contains a valid PICO-8 folder with required files!\n"
			BIOS_DIR="/run/muos/storage/bios"

			P8_REQ="$(GET_ARCHIVE_BYTES "$ARCHIVE" "pico-8/")"
			! CHECK_SPACE_FOR_DEST "$P8_REQ" "$BIOS_DIR" && ALL_DONE 1

			if unzip -o -j "$ARCHIVE" "pico-8/*" -d "${BIOS_DIR}/pico-8/"; then
				printf "Extracted 'pico-8' Folder to '%s'\n" "$BIOS_DIR"
			else
				printf "Failed to Extract 'pico-8' Folder\n"
				ALL_DONE 1
			fi
		fi
		;;
	*.muxthm)
		printf "Detected Theme Package\nMoving archive to 'MUOS/theme'\n"
		mv "$ARCHIVE" "/run/muos/storage/theme/"
		;;
	*.muxcat)
		printf "Detected Catalogue Package\nMoving archive to 'MUOS/package/catalogue'\n"
		mv "$ARCHIVE" "/run/muos/storage/package/catalogue/"
		;;
	*.muxcfg)
		printf "Detected RetroArch Configuration Package\nMoving archive to 'MUOS/package/config'\n"
		mv "$ARCHIVE" "/run/muos/storage/package/config/"
		;;
	*.muxapp | *.muxupd | *.muxzip | *.zip)
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		if ! EXTRACT_ARCHIVE "Archive" "$ARCHIVE" "/"; then
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi
		;;
	*) printf "\nNo Extraction Method '%s'\n" "$ARCHIVE_NAME" ;;
esac

printf "Correcting Permissions...\n"
chmod -R 755 /opt/muos

# Only allow update archives to run the update script!
case "$ARCHIVE_NAME" in
	*.muxupd)
		UPDATE_SCRIPT=/opt/update.sh
		if [ -s "$UPDATE_SCRIPT" ]; then
			printf "Running Update Script...\n"
			chmod 755 "$UPDATE_SCRIPT"
			"$UPDATE_SCRIPT"
			rm -f "$UPDATE_SCRIPT"
		fi
		;;
esac

mkdir -p "/opt/muos/update/installed"
: >"/opt/muos/update/installed/$ARCHIVE_NAME.done"

ALL_DONE 0
