#!/bin/sh
# NEVER_CANCEL: 1
# The following script reads a manifest file to determine which files to back up,
# where to back them up, and whether to do it in individual or batch mode.
# It supports both individual backups and batch processing of multiple files.

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh
. /opt/muos/script/var/ui.sh

LOG_INFO "$0" 0 "BACKUP" "Backup script started"

TASK_IS_NATIVE || FRONTEND stop

SET_VAR "system" "foreground_process" "muxbackup"

MANIFEST_FILE="/tmp/muxbackup_manifest.txt"
ERROR_FLAG=0

BACKUP_FOLDER="BACKUP"

SD1="$(GET_VAR "device" "storage/rom/mount")"
SD2="$(GET_VAR "device" "storage/sdcard/mount")"
USB="$(GET_VAR "device" "storage/usb/mount")"

MERGE_ALL=$1
LOG_INFO "$0" 0 "BACKUP" "$(printf "Merge mode: %s" "$MERGE_ALL")"

# Check if manifest file exists
if [ ! -f "$MANIFEST_FILE" ]; then
	LOG_ERROR "$0" 0 "BACKUP" "$(printf "Manifest file not found: '%s'" "$MANIFEST_FILE")"
	TASK_ERROR "manifest_missing" "$(printf "Manifest file not found: %s" "$MANIFEST_FILE")"
	ERROR_FLAG=1
elif ! read -r SRC_MODE DEST_MNT <"$MANIFEST_FILE"; then
	LOG_ERROR "$0" 0 "BACKUP" "$(printf "Failed to read manifest header from: '%s'" "$MANIFEST_FILE")"
	TASK_ERROR "manifest_unreadable" "$(printf "Could not read the manifest header from %s" "$MANIFEST_FILE")"
	ERROR_FLAG=1
elif [ -z "$SRC_MODE" ] || [ -z "$DEST_MNT" ]; then
	LOG_ERROR "$0" 0 "BACKUP" "Invalid manifest header format"
	TASK_ERROR "manifest_invalid" "Invalid manifest header, expected SRC_MODE and DEST_MNT."
	ERROR_FLAG=1
elif [ "$SRC_MODE" != "INDIVIDUAL" ] && [ "$SRC_MODE" != "BATCH" ]; then
	LOG_ERROR "$0" 0 "BACKUP" "$(printf "Invalid SRC_MODE in manifest: '%s'" "$SRC_MODE")"
	TASK_ERROR "manifest_invalid" "$(printf "Invalid SRC_MODE in the manifest: %s" "$SRC_MODE")"
	ERROR_FLAG=1
elif [ "$DEST_MNT" != "SD1" ] && [ "$DEST_MNT" != "SD2" ] && [ "$DEST_MNT" != "USB" ]; then
	LOG_ERROR "$0" 0 "BACKUP" "$(printf "Invalid DEST_MNT in manifest: '%s'" "$DEST_MNT")"
	TASK_ERROR "manifest_invalid" "$(printf "Invalid DEST_MNT in the manifest: %s" "$DEST_MNT")"
	ERROR_FLAG=1
fi

if [ "$ERROR_FLAG" -ne 1 ]; then
	case "$DEST_MNT" in
		SD1) DEST_PATH="$SD1/$BACKUP_FOLDER" ;;
		SD2) DEST_PATH="$SD2/$BACKUP_FOLDER" ;;
		USB) DEST_PATH="$USB/$BACKUP_FOLDER" ;;
	esac
	LOG_INFO "$0" 0 "BACKUP" "$(printf "Destination path: '%s' (mode: %s)" "$DEST_PATH" "$SRC_MODE")"
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
			TASK_ERROR "manifest_invalid" "$(printf "Invalid manifest line %s" "$LINE_NUM")"
			ERROR_FLAG=1
			break
		fi

		CREATOR="/opt/muos/script/archive/$SRC_SHORTNAME.sh"
		if [ ! -r "$CREATOR" ]; then
			TASK_DETAIL "$(printf "Skipping unsupported archive: %s" "$SRC_SHORTNAME")"
			continue
		fi

		# shellcheck disable=SC1090
		. "$CREATOR" || {
			TASK_DETAIL "$(printf "Invalid creator for %s, cannot be sourced" "$SRC_SHORTNAME")"
			continue
		}

		if ! command -v ARC_CREATE >/dev/null 2>&1; then
			TASK_DETAIL "$(printf "Invalid creator for %s, missing 'ARC_CREATE'" "$SRC_SHORTNAME")"
			ARC_UNSET
			continue
		fi

		ARC_CREATE || {
			TASK_DETAIL "$(printf "Invalid creator for %s, 'ARC_CREATE' failed" "$SRC_SHORTNAME")"
			ARC_UNSET
			continue
		}

		if command -v ARC_CREATE_PRE >/dev/null 2>&1; then
			if ! ARC_CREATE_PRE; then
				TASK_DETAIL "$(printf "Pre-create hook failed for %s, skipping" "$SRC_SHORTNAME")"
				ARC_UNSET
				continue
			fi
		fi

		if [ -z "${SRC}" ] || [ -z "${LABEL}" ]; then
			TASK_DETAIL "$(printf "Invalid creator for %s, missing 'SRC' or 'LABEL'" "$SRC_SHORTNAME")"
			ARC_UNSET
			continue
		fi

		SRC_SUFFIX="${SRC}/${SRC_SHORTNAME}"

		if [ ! -e "$SRC_SUFFIX" ]; then
			TASK_DETAIL "$(printf "Source path not found: %s" "$SRC_SUFFIX")"
			ARC_UNSET
			continue
		fi

		if [ "$ERROR_FLAG" -eq 0 ]; then
			if [ "$MERGE_ALL" -eq 1 ]; then
				ZIP_FILE="MustardOS.FullBackup.$(date +%Y%m%d).muxzip"

				TASK_STATUS "$(printf "Adding %s to archive" "$LABEL")"
				TASK_DETAIL "$ZIP_FILE"
			else
				CAP_SRC_SN=$(CAPITALISE "$SRC_SHORTNAME")
				ZIP_FILE="MustardOS.${CAP_SRC_SN}.$(date +%Y%m%d).muxzip"

				TASK_STATUS "$(printf "Creating %s archive" "$LABEL")"
				TASK_DETAIL "$ZIP_FILE"
			fi

			TASK_PROGRESS "$INDEX" "$TOTAL"

			DEST_FILE="${DEST_PATH}/${ZIP_FILE}"
			LOG_INFO "$0" 0 "BACKUP" "$(printf "Archiving '%s' -> '%s'" "$SRC_SUFFIX" "$DEST_FILE")"
			if CREATE_ARCHIVE "$SRC_SHORTNAME" "$DEST_FILE" "$SRC_MNT" "$SRC_SHORTNAME" "$SRC_SUFFIX" "$COMP"; then
				[ "$MERGE_ALL" -eq 1 ] && WHAT_DO="Added" || WHAT_DO="Created"
				LOG_SUCCESS "$0" 0 "BACKUP" "$(printf "%s '%s'" "$WHAT_DO" "$LABEL")"
				TASK_DETAIL "$(printf "%s '%s' successfully" "$WHAT_DO" "$LABEL")"
				ARC_STATUS=0
			else
				LOG_ERROR "$0" 0 "BACKUP" "$(printf "Failed to add '%s' for '%s'" "$SRC_SUFFIX" "$SRC_SHORTNAME")"
				TASK_ERROR "archive_failed" "$(printf "Failed to archive %s" "$SRC_SHORTNAME")"
				ERROR_FLAG=1
				ARC_STATUS=1
			fi

			if command -v ARC_CREATE_POST >/dev/null 2>&1; then
				ARC_CREATE_POST "$ARC_STATUS"
			fi

			ARC_UNSET

			INDEX=$((INDEX + 1))
			TASK_IS_NATIVE || sleep 1
		fi
	done <"$MANIFEST_FILE"
fi

if [ "$ERROR_FLAG" -ne 0 ]; then
	LOG_ERROR "$0" 0 "BACKUP" "Errors occurred during backup process"
	TASK_ERROR "backup_incomplete" "Errors occurred during the backup."
	TASK_IS_NATIVE || sleep 3
else
	LOG_SUCCESS "$0" 0 "BACKUP" "Backup completed successfully"
	TASK_COMPLETE "Backup completed successfully"
fi

# Remove the manifest file
[ -f "$MANIFEST_FILE" ] && rm -f "$MANIFEST_FILE"

TASK_STATUS "Sync Filesystem"
sync

TASK_IS_NATIVE || {
	sleep 3
	FRONTEND start backup
}

SET_VAR "system" "foreground_process" "muxfrontend"

ARCHIVE_CACHE_CLEANUP
exit "$ERROR_FLAG"
