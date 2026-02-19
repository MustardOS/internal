#!/bin/sh
# The following script reads a manifest file to determine which files to back up,
# where to back them up, and whether to do it in individual or batch mode.
# It supports both individual backups and batch processing of multiple files.

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

SET_VAR "system" "foreground_process" "muxbackup"

MANIFEST_FILE="/tmp/muxbackup_manifest.txt"
ERROR_FLAG=0

BACKUP_FOLDER="BACKUP"

SD1="$(GET_VAR "device" "storage/rom/mount")"
SD2="$(GET_VAR "device" "storage/sdcard/mount")"
USB="$(GET_VAR "device" "storage/usb/mount")"

MERGE_ALL=$1

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
	printf "\nManifest file not found: %s\n" "$MANIFEST_FILE"
	ERROR_FLAG=1
elif ! read -r SRC_MODE DEST_MNT <"$MANIFEST_FILE"; then
	printf "\nFailed to read manifest header from: %s\n" "$MANIFEST_FILE"
	ERROR_FLAG=1
elif [ -z "$SRC_MODE" ] || [ -z "$DEST_MNT" ]; then
	printf "\nInvalid manifest header format. Expected: SRC_MODE DEST_MNT\n"
	ERROR_FLAG=1
elif [ "$SRC_MODE" != "INDIVIDUAL" ] && [ "$SRC_MODE" != "BATCH" ]; then
	printf "\nInvalid SRC_MODE in manifest: %s\n" "$SRC_MODE"
	ERROR_FLAG=1
elif [ "$DEST_MNT" != "SD1" ] && [ "$DEST_MNT" != "SD2" ] && [ "$DEST_MNT" != "USB" ]; then
	printf "\nInvalid DEST_MNT in manifest: %s\n" "$DEST_MNT"
	ERROR_FLAG=1
fi

if [ "$ERROR_FLAG" -ne 1 ]; then
	case "$DEST_MNT" in
		SD1) DEST_PATH="$SD1/$BACKUP_FOLDER" ;;
		SD2) DEST_PATH="$SD2/$BACKUP_FOLDER" ;;
		USB) DEST_PATH="$USB/$BACKUP_FOLDER" ;;
	esac
	[ ! -d "$DEST_PATH" ] && mkdir -p "$DEST_PATH"
fi

LINE_NUM=0
INDEX=1

TOTAL=$(($(wc -l <"$MANIFEST_FILE") - 1))
[ "$TOTAL" -lt 0 ] && TOTAL=0

if [ "$ERROR_FLAG" -ne 1 ]; then
	while read -r SRC_MNT SRC_SHORTNAME; do
		LINE_NUM=$((LINE_NUM + 1))

		if [ "$LINE_NUM" -eq 1 ]; then
			continue
		elif [ "$ERROR_FLAG" -ne 0 ]; then
			break
		elif [ -z "$SRC_MNT" ] || [ -z "$SRC_SHORTNAME" ]; then
			printf "\nInvalid line %s in manifest: %s %s\n" "$LINE_NUM" "$SRC_MNT" "$SRC_SHORTNAME"
			ERROR_FLAG=1
			break
		fi

		CREATOR="/opt/muos/script/archive/$SRC_SHORTNAME.sh"
		if [ ! -r "$CREATOR" ]; then
			printf "\nSkipping unsupported archive: %s\n" "$SRC_SHORTNAME"
			continue
		fi

		# shellcheck disable=SC1090
		. "$CREATOR" || {
			printf "\n\nInvalid creator for: %s\nCreator not executable or cannot be sourced\n\n" "$SRC_SHORTNAME"
			continue
		}

		if ! command -v ARC_CREATE >/dev/null 2>&1; then
			printf "\n\nInvalid extractor for: %s\nMissing 'ARC_CREATE' function\n\n" "$SRC_SHORTNAME"
			ARC_UNSET
			continue
		fi

		ARC_CREATE || {
			printf "\n\nInvalid extractor for: %s\nCannot source 'ARC_CREATE' function\n\n" "$SRC_SHORTNAME"
			ARC_UNSET
			continue
		}

		if command -v ARC_CREATE_PRE >/dev/null 2>&1; then
			if ! ARC_CREATE_PRE; then
				printf "\nPre-create hook failed for: %s — skipping\n" "$SRC_SHORTNAME"
				ARC_UNSET
				continue
			fi
		fi

		if [ -z "${SRC}" ] || [ -z "${LABEL}" ]; then
			printf "\n\nInvalid extractor for: %s\nMissing 'SRC' or 'LABEL' variables\n\n" "$SRC_SHORTNAME"
			ARC_UNSET
			continue
		fi

		SRC_SUFFIX="${SRC}/${SRC_SHORTNAME}"

		if [ ! -e "$SRC_SUFFIX" ]; then
			printf "\nSource path not found: %s\n" "$SRC_SUFFIX"
			ARC_UNSET
			continue
		fi

		if [ "$ERROR_FLAG" -eq 0 ]; then
			if [ "$MERGE_ALL" -eq 1 ]; then
				ZIP_FILE="MustardOS.FullBackup.$(date +%Y%m%d).muxzip"

				printf "(%s/%s) Adding %s to Archive: %s\n" "$INDEX" "$TOTAL" "$LABEL" "$ZIP_FILE"
			else
				CAP_SRC_SN=$(CAPITALISE "$SRC_SHORTNAME")
				ZIP_FILE="MustardOS.${CAP_SRC_SN}.$(date +%Y%m%d).muxzip"

				printf "(%s/%s) Creating %s Archive: %s\n" "$INDEX" "$TOTAL" "$LABEL" "$ZIP_FILE"
			fi

			DEST_FILE="${DEST_PATH}/${ZIP_FILE}"
			if CREATE_ARCHIVE "$SRC_SHORTNAME" "$DEST_FILE" "$SRC_MNT" "$SRC_SHORTNAME" "$SRC_SUFFIX" "$COMP"; then
				[ "$MERGE_ALL" -eq 1 ] && WHAT_DO="Added" || WHAT_DO="Created"
				printf "%s '%s' successfully\n\n" "$WHAT_DO" "$LABEL"
				ARC_STATUS=0
			else
				printf "Failed to add %s for %s\n\n" "$SRC_SUFFIX" "$SRC_SHORTNAME"
				ERROR_FLAG=1
				ARC_STATUS=1
			fi

			if command -v ARC_CREATE_POST >/dev/null 2>&1; then
				ARC_CREATE_POST "$ARC_STATUS"
			fi

			ARC_UNSET

			INDEX=$((INDEX + 1))
			sleep 1
		fi
	done <"$MANIFEST_FILE"
fi

if [ "$ERROR_FLAG" -ne 0 ]; then
	printf "Errors occurred during the backup process\n\n"
	sleep 3
else
	printf "Backup completed successfully\n\n"
fi

# Remove the manifest file
[ -f "$MANIFEST_FILE" ] && rm -f "$MANIFEST_FILE"

echo "Sync Filesystem"
sync

sleep 3
FRONTEND start backup

SET_VAR "system" "foreground_process" "muxfrontend"

exit 0
