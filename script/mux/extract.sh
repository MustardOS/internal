#!/bin/sh
# NEVER_CANCEL: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh
. /opt/muos/script/var/ui.sh

LOG_INFO "$0" 0 "EXTRACT" "Archive extraction started"

TASK_IS_NATIVE || { [ -z "${THEME_INSTALLING:-}" ] && FRONTEND stop; }

ALL_DONE() {
	[ -e "/tmp/no_fe" ] && exit 0

	LOG_INFO "$0" 0 "EXTRACT" "$(printf "Cleanup and exit (code: %s)" "${1:-0}")"
	TASK_STATUS "Sync Filesystem"
	sync

	# A failure has already reported itself, saying it completed would overwrite that
	[ "${1:-0}" -eq 0 ] && TASK_COMPLETE "Extraction complete"
	TASK_IS_NATIVE || sleep 2

	TASK_IS_NATIVE || { [ -z "${THEME_INSTALLING:-}" ] && FRONTEND start "${FRONTEND_START_PROGRAM:-archive}"; }

	exit "${1:-0}"
}

REJECT_UNSAFE_ARCHIVE() {
	"$MUOS_LOG_BIN" error "$0" 0 "EXTRACT" "$(printf "Rejected archive with unsafe paths: '%s'" "${1##*/}")"
	TASK_ERROR "archive_unsafe" "$(printf "Archive blocked: '%s' contains unsafe file paths" "${1##*/}")"
	ALL_DONE 1
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	LOG_ERROR "$0" 0 "EXTRACT" "$(printf "Invalid argument count: %s" "$#")"
	TASK_ERROR "bad_arguments" "$(printf "Usage: %s <archive> [mux module]" "$0")"
	ALL_DONE 1
fi

ARCHIVE="$1"
if [ ! -e "$ARCHIVE" ]; then
	LOG_ERROR "$0" 0 "EXTRACT" "$(printf "Archive not found: '%s'" "$ARCHIVE")"
	TASK_ERROR "archive_missing" "$(printf "Archive '%s' was not found" "$ARCHIVE")"
	ALL_DONE 1
fi

ARCHIVE_NAME="${ARCHIVE##*/}"
BASENAME="${ARCHIVE_NAME%.*}"
FRONTEND_START_PROGRAM="${2:-archive}"

LOG_INFO "$0" 0 "EXTRACT" "$(printf "Inspecting archive: '%s'" "$ARCHIVE_NAME")"
TASK_STATUS "Inspecting Archive..."

case "$ARCHIVE_NAME" in
	pico-8_*)
		LOG_INFO "$0" 0 "EXTRACT" "Detected PICO-8 archive"
		if unzip -l "$ARCHIVE" | awk '
			$NF ~ /^pico-8\// {FOLDERS[$NF]=1}
			$NF ~ /^pico-8\/(pico8_64|pico8\.dat)$/ {FILES[$NF]=1}
			END {
				if ("pico-8/" in FOLDERS && "pico-8/pico8_64" in FILES && "pico-8/pico8.dat" in FILES) exit 0; else exit 1
			}'; then
			TASK_STATUS "Archive contains a valid PICO-8 folder with required files!"
			BIOS_DIR="$MUOS_STORE_DIR/bios"

			P8_REQ="$(GET_ARCHIVE_BYTES "$ARCHIVE" "pico-8/")"
			! CHECK_SPACE_FOR_DEST "$P8_REQ" "bios" && ALL_DONE 1

			if unzip -o -j "$ARCHIVE" "pico-8/*" -d "${BIOS_DIR}/pico-8/" &&
				mkdir -p "$MUOS_SHARE_DIR/application/Splore" &&
				cp "$MUOS_SHARE_DIR/emulator/pico8/splore.txt" "$MUOS_SHARE_DIR/application/Splore/mux_launch.sh" &&
				chmod +x "$MUOS_SHARE_DIR/application/Splore/mux_launch.sh"; then
				LOG_SUCCESS "$0" 0 "EXTRACT" "$(printf "Extracted PICO-8 to '%s'" "$BIOS_DIR")"
				TASK_DETAIL "$(printf "Extracted 'pico-8' folder to '%s'" "$BIOS_DIR")"
			else
				LOG_ERROR "$0" 0 "EXTRACT" "Failed to extract PICO-8 folder"
				TASK_ERROR "extract_failed" "The 'pico-8' folder could not be extracted."
				ALL_DONE 1
			fi
		fi
		;;
	*.muxthm)
		LOG_INFO "$0" 0 "EXTRACT" "Detected theme archive (.muxthm)"
		SAFE_ARCHIVE "$ARCHIVE" || REJECT_UNSAFE_ARCHIVE "$ARCHIVE"
		if ! EXTRACT_ARCHIVE "Theme" "$ARCHIVE" "$MUOS_STORE_DIR/theme/$BASENAME"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Theme extraction failed"
			TASK_ERROR "extract_failed" "The archive could not be extracted."
			ALL_DONE 1
		fi
		;;
	*.muxcat)
		LOG_INFO "$0" 0 "EXTRACT" "Detected catalogue package - moving to staging"
		TASK_STATUS "Detected Catalogue Package"
		TASK_DETAIL "Moving archive to 'MUOS/package/catalogue'"
		if ! mkdir -p "$MUOS_STORE_DIR/package/catalogue" || ! mv "$ARCHIVE" "$MUOS_STORE_DIR/package/catalogue/"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Failed to move catalogue package to staging"
			TASK_ERROR "move_failed" "The catalogue package could not be moved into place."
			ALL_DONE 1
		fi
		;;
	*.muxcfg)
		LOG_INFO "$0" 0 "EXTRACT" "Detected RetroArch config package - moving to staging"
		TASK_STATUS "Detected RetroArch Configuration Package"
		TASK_DETAIL "Moving archive to 'MUOS/package/config'"
		if ! mkdir -p "$MUOS_STORE_DIR/package/config" || ! mv "$ARCHIVE" "$MUOS_STORE_DIR/package/config/"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Failed to move RetroArch configuration package to staging"
			TASK_ERROR "move_failed" "The configuration package could not be moved into place."
			ALL_DONE 1
		fi
		;;
	*.muxalt)
		LOG_INFO "$0" 0 "EXTRACT" "Detected theme alternative archive (.muxalt)"
		SAFE_ARCHIVE "$ARCHIVE" || REJECT_UNSAFE_ARCHIVE "$ARCHIVE"

		ACTIVE="$(GET_VAR "config" "theme/active")"
		if ! EXTRACT_ARCHIVE "Theme Alternative" "$ARCHIVE" "$MUOS_STORE_DIR/theme/$ACTIVE"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Theme alternative extraction failed"
			TASK_ERROR "extract_failed" "The archive could not be extracted."
			ALL_DONE 1
		fi

		if ! UPDATE_BOOTLOGO; then
			LOG_WARN "$0" 0 "EXTRACT" "Failed to update bootlogo after theme alternative extraction"
		fi
		;;
	*.muxapp)
		LOG_INFO "$0" 0 "EXTRACT" "Detected application archive (.muxapp)"
		SAFE_ARCHIVE "$ARCHIVE" || REJECT_UNSAFE_ARCHIVE "$ARCHIVE"

		if ! EXTRACT_ARCHIVE "Application" "$ARCHIVE" "$MUOS_STORE_DIR/application"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Application extraction failed"
			TASK_ERROR "extract_failed" "The archive could not be extracted."
			ALL_DONE 1
		fi
		;;
	*.muxupd)
		LOG_INFO "$0" 0 "EXTRACT" "Detected system update archive (.muxupd)"
		SAFE_ARCHIVE "$ARCHIVE" || REJECT_UNSAFE_ARCHIVE "$ARCHIVE"

		if ! EXTRACT_ARCHIVE "System Update" "$ARCHIVE" "/"; then
			LOG_ERROR "$0" 0 "EXTRACT" "System update extraction failed"
			TASK_ERROR "extract_failed" "The archive could not be extracted."
			ALL_DONE 1
		fi
		;;
	*.muxzip)
		LOG_INFO "$0" 0 "EXTRACT" "Detected multi-section archive (.muxzip)"
		SAFE_ARCHIVE "$ARCHIVE" || REJECT_UNSAFE_ARCHIVE "$ARCHIVE"

		TASK_STATUS "Scanning Archive Directories..."
		if ! TOP_LEVEL="$(GET_TOP_LEVEL_DIRS "$ARCHIVE")"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Failed to scan archive directories"
			TASK_ERROR "scan_failed" "The archive contents could not be read."
			ALL_DONE 1
		fi
		LOG_DEBUG "$0" 0 "EXTRACT" "$(printf "Top-level entries: %s" "$TOP_LEVEL")"

		for TOP in $TOP_LEVEL; do
			DEST=""
			LABEL=""
			PATTERN="${TOP}/*"

			LOG_DEBUG "$0" 0 "EXTRACT" "$(printf "Processing section: '%s'" "$TOP")"

			EXTRACTOR="/opt/muos/script/archive/$TOP.sh"
			if [ ! -r "$EXTRACTOR" ]; then
				LOG_WARN "$0" 0 "EXTRACT" "$(printf "Skipping unsupported section: '%s'" "$TOP")"
				TASK_DETAIL "$(printf "Skipping unsupported section: %s" "$TOP")"
				continue
			fi

			# shellcheck disable=SC1090
			. "$EXTRACTOR" || {
				TASK_DETAIL "$(printf "Invalid extractor for %s, cannot be sourced" "$TOP")"
				continue
			}

			if ! command -v ARC_EXTRACT >/dev/null 2>&1; then
				TASK_DETAIL "$(printf "Invalid extractor for %s, missing 'ARC_EXTRACT'" "$TOP")"
				ARC_UNSET
				continue
			fi

			ARC_EXTRACT || {
				TASK_DETAIL "$(printf "Invalid extractor for %s, 'ARC_EXTRACT' failed" "$TOP")"
				ARC_UNSET
				continue
			}

			if command -v ARC_EXTRACT_PRE >/dev/null 2>&1; then
				if ! ARC_EXTRACT_PRE; then
					TASK_DETAIL "$(printf "Pre-extract hook failed for %s, skipping" "$TOP")"
					ARC_UNSET
					continue
				fi
			fi

			if [ -z "${DEST:-}" ] || [ -z "${LABEL:-}" ]; then
				TASK_DETAIL "$(printf "Invalid extractor for %s, missing 'DEST' or 'LABEL'" "$TOP")"
				ARC_UNSET
				continue
			fi

			REQ="$(GET_ARCHIVE_BYTES "$ARCHIVE" "$TOP/")"
			! CHECK_SPACE_FOR_DEST "$REQ" "$TOP" && ALL_DONE 1

			TASK_STATUS "$(printf "Extracting '%s'" "$LABEL")"
			TASK_DETAIL "$(printf "Destination '%s'" "$DEST")"
			if EXTRACT_ARCHIVE "$LABEL" "$ARCHIVE" "$DEST" "$PATTERN"; then
				LOG_SUCCESS "$0" 0 "EXTRACT" "$(printf "Extracted '%s' to '%s'" "$LABEL" "$DEST")"
				TASK_DETAIL "$(printf "Extracted '%s' successfully" "$LABEL")"
				ARC_STATUS=0
			else
				LOG_ERROR "$0" 0 "EXTRACT" "$(printf "Failed to extract '%s'" "$LABEL")"
				TASK_DETAIL "$(printf "Failed to extract '%s'" "$LABEL")"
				ARC_STATUS=1
			fi

			if command -v ARC_EXTRACT_POST >/dev/null 2>&1; then
				if ! ARC_EXTRACT_POST "$ARC_STATUS"; then
					LOG_WARN "$0" 0 "EXTRACT" "Post-extract hook failed"
				fi
			fi

			ARC_UNSET
		done

		# Special case for core downloads - we run the control script
		# to initialise any control based changes for emulators
		if [ "$FRONTEND_START_PROGRAM" = "coredown" ]; then
			/opt/muos/script/device/control.sh || {
				LOG_ERROR "$0" 0 "EXTRACT" "Failed to initialise control script after core download"
				TASK_ERROR "control_failed" "Control initialisation failed after the core download."
				ALL_DONE 1
			}
		fi
		;;
	*)
		LOG_WARN "$0" 0 "EXTRACT" "$(printf "No extraction method for: '%s'" "$ARCHIVE_NAME")"
		TASK_ERROR "no_method" "$(printf "There is no extraction method for '%s'" "$ARCHIVE_NAME")"
		;;
esac

LOG_DEBUG "$0" 0 "EXTRACT" "Correcting permissions under /opt/muos"
TASK_STATUS "Correcting Permissions..."
if ! chmod -R 755 /opt/muos; then
	LOG_WARN "$0" 0 "EXTRACT" "Failed to correct permissions under /opt/muos"
	TASK_STATUS "Permission Correction Failed..."
fi

# Only allow update archives to run the update script!
case "$ARCHIVE_NAME" in
	*.muxupd)
		UPDATE_SCRIPT=/opt/update.sh
		if [ -s "$UPDATE_SCRIPT" ]; then
			LOG_INFO "$0" 0 "EXTRACT" "$(printf "Running update script: '%s'" "$UPDATE_SCRIPT")"
			TASK_STATUS "Running Update Script..."
			chmod 755 "$UPDATE_SCRIPT"
			if ! "$UPDATE_SCRIPT"; then
				LOG_ERROR "$0" 0 "EXTRACT" "Update script failed"
				TASK_ERROR "update_failed" "The update script did not complete."
				rm -f "$UPDATE_SCRIPT"
				ALL_DONE 1
			fi
			rm -f "$UPDATE_SCRIPT"
		fi
		;;
esac

if ! mkdir -p "/opt/muos/update/installed" || ! : >"/opt/muos/update/installed/$ARCHIVE_NAME.done"; then
	LOG_ERROR "$0" 0 "EXTRACT" "Failed to mark archive as installed"
	TASK_ERROR "install_mark_failed" "The archive could not be marked as installed."
	ALL_DONE 1
fi

LOG_SUCCESS "$0" 0 "EXTRACT" "$(printf "Marked '%s' as installed" "$ARCHIVE_NAME")"
ALL_DONE 0
