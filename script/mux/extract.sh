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

ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
STORAGE_BASE="/run/muos/storage"

case "$ARCHIVE_NAME" in
	pico-8_*)
		if unzip -l "$ARCHIVE" | awk '
			$NF ~ /^pico-8\// {FOLDERS[$NF]=1}
			$NF ~ /^pico-8\/(pico8_64|pico8\.dat)$/ {FILES[$NF]=1}
			END {
				if ("pico-8/" in FOLDERS && "pico-8/pico8_64" in FILES && "pico-8/pico8.dat" in FILES) exit 0; else exit 1
			}'; then
			printf "\nArchive contains a valid PICO-8 folder with required files!\n"
			BIOS_DIR="$STORAGE_BASE/bios"

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
		mv "$ARCHIVE" "$STORAGE_BASE/theme/"
		;;
	*.muxcat)
		printf "Detected Catalogue Package\nMoving archive to 'MUOS/package/catalogue'\n"
		mv "$ARCHIVE" "$STORAGE_BASE/package/catalogue/"
		;;
	*.muxcfg)
		printf "Detected RetroArch Configuration Package\nMoving archive to 'MUOS/package/config'\n"
		mv "$ARCHIVE" "$STORAGE_BASE/package/config/"
		;;
	*.muxalt)
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		if ! EXTRACT_ARCHIVE "Theme Alternative" "$ARCHIVE" "$STORAGE_BASE/theme/active"; then
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi

		UPDATE_BOOTLOGO
		;;
	*.muxapp)
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		if ! EXTRACT_ARCHIVE "Application" "$ARCHIVE" "$ROM_MOUNT/MUOS/application"; then
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi
		;;
	*.muxupd)
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		if ! EXTRACT_ARCHIVE "System Update" "$ARCHIVE" "/"; then
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi
		;;
	*.muxzip)
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		printf "Scanning Archive Directories...\n"
		TOP_LEVEL="$(unzip -Z1 "$ARCHIVE" 2>/dev/null | awk -F/ 'NF>1 {print $1}' | sort -u)"

		for TOP in $TOP_LEVEL; do
			DEST=""
			LABEL=""
			PATTERN="${TOP}/*"

			case "$TOP" in
				application)
					DEST="$ROM_MOUNT/MUOS"
					LABEL="Application"
					;;
				bios)
					DEST="$STORAGE_BASE"
					LABEL="BIOS"
					;;
				catalogue)
					DEST="$STORAGE_BASE/info"
					LABEL="Catalogue"
					;;
				collection)
					DEST="$STORAGE_BASE/info"
					LABEL="Collection"
					;;
				history)
					DEST="$STORAGE_BASE/info"
					LABEL="History"
					;;
				info)
					DEST="$STORAGE_BASE"
					LABEL="Info"
					;;
				init)
					DEST="$STORAGE_BASE"
					LABEL="Init Scripts"
					;;
				language)
					DEST="$STORAGE_BASE"
					LABEL="Language"
					;;
				name)
					DEST="$STORAGE_BASE/info"
					LABEL="Name Configuration"
					;;
				network)
					DEST="$STORAGE_BASE"
					LABEL="Network Profiles"
					;;
				package)
					DEST="$STORAGE_BASE"
					LABEL="Package"
					;;
				save)
					DEST="$STORAGE_BASE"
					LABEL="Save Files"
					;;
				syncthing)
					DEST="$STORAGE_BASE"
					LABEL="Syncthing Configuration"
					;;
				theme)
					DEST="$STORAGE_BASE"
					LABEL="Theme"
					;;
				track)
					DEST="$STORAGE_BASE/info"
					LABEL="Playtime Data"
					;;
				bin | etc | home | lib | lib32 | lib64 | mnt | opt | roms | root | run | sbin | usr | var)
					DEST="/"
					LABEL="System ($TOP)"
					;;
				*)
					printf "\nSkipping Unrecognised Directory: %s\n" "$TOP"
					continue
					;;
			esac

			REQ="$(GET_ARCHIVE_BYTES "$ARCHIVE" "$TOP/")"
			! CHECK_SPACE_FOR_DEST "$REQ" "$DEST" && ALL_DONE 1

			printf "\nExtracting '%s' to '%s'\n" "$LABEL" "$DEST"
			if EXTRACT_ARCHIVE "$LABEL" "$ARCHIVE" "$DEST" "$PATTERN"; then
				printf "Extracted '%s' successfully\n" "$LABEL"
			else
				printf "Failed to extract '%s'\n" "$LABEL"
				continue
			fi
		done
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
