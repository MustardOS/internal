#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

LOG_INFO "$0" 0 "EXTRACT" "Archive extraction started"

[ -z "${THEME_INSTALLING:-}" ] && FRONTEND stop

ALL_DONE() {
	[ -e "/tmp/no_fe" ] && exit 0

	LOG_INFO "$0" 0 "EXTRACT" "$(printf "Cleanup and exit (code: %s)" "${1:-0}")"
	printf "\nSync Filesystem\n"
	sync

	printf "All Done!\n"
	sleep 2

	[ -z "${THEME_INSTALLING:-}" ] && FRONTEND start "${FRONTEND_START_PROGRAM:-archive}"

	exit "${1:-0}"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	LOG_ERROR "$0" 0 "EXTRACT" "$(printf "Invalid argument count: %s" "$#")"
	printf "Usage: %s <archive> [mux module]\n" "$0"
	ALL_DONE 1
fi

ARCHIVE="$1"
if [ ! -e "$ARCHIVE" ]; then
	LOG_ERROR "$0" 0 "EXTRACT" "$(printf "Archive not found: '%s'" "$ARCHIVE")"
	printf "\nError: Archive '%s' not found\n" "$ARCHIVE"
	ALL_DONE 1
fi

ARCHIVE_NAME="${ARCHIVE##*/}"
BASENAME="${ARCHIVE_NAME%.*}"
FRONTEND_START_PROGRAM="${2:-archive}"

LOG_INFO "$0" 0 "EXTRACT" "$(printf "Inspecting archive: '%s'" "$ARCHIVE_NAME")"
printf "Inspecting Archive...\n"

case "$ARCHIVE_NAME" in
	pico-8_*)
		LOG_INFO "$0" 0 "EXTRACT" "Detected PICO-8 archive"
		if unzip -l "$ARCHIVE" | awk '
			$NF ~ /^pico-8\// {FOLDERS[$NF]=1}
			$NF ~ /^pico-8\/(pico8_64|pico8\.dat)$/ {FILES[$NF]=1}
			END {
				if ("pico-8/" in FOLDERS && "pico-8/pico8_64" in FILES && "pico-8/pico8.dat" in FILES) exit 0; else exit 1
			}'; then
			printf "\nArchive contains a valid PICO-8 folder with required files!\n"
			BIOS_DIR="$MUOS_STORE_DIR/bios"

			P8_REQ="$(GET_ARCHIVE_BYTES "$ARCHIVE" "pico-8/")"
			! CHECK_SPACE_FOR_DEST "$P8_REQ" "bios" && ALL_DONE 1

			if unzip -o -j "$ARCHIVE" "pico-8/*" -d "${BIOS_DIR}/pico-8/" &&
				mkdir -p "$MUOS_SHARE_DIR/application/Splore" &&
				cp "$MUOS_SHARE_DIR/emulator/pico8/splore.txt" "$MUOS_SHARE_DIR/application/Splore/mux_launch.sh" &&
				chmod +x "$MUOS_SHARE_DIR/application/Splore/mux_launch.sh"; then
				LOG_SUCCESS "$0" 0 "EXTRACT" "$(printf "Extracted PICO-8 to '%s'" "$BIOS_DIR")"
				printf "Extracted 'pico-8' Folder to '%s'\n" "$BIOS_DIR"
			else
				LOG_ERROR "$0" 0 "EXTRACT" "Failed to extract PICO-8 folder"
				printf "Failed to Extract 'pico-8' Folder\n"
				ALL_DONE 1
			fi
		fi
		;;
	*.muxthm)
		LOG_INFO "$0" 0 "EXTRACT" "Detected theme archive (.muxthm)"
		if ! EXTRACT_ARCHIVE "Theme" "$ARCHIVE" "$MUOS_STORE_DIR/theme/$BASENAME"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Theme extraction failed"
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi
		;;
	*.muxcat)
		LOG_INFO "$0" 0 "EXTRACT" "Detected catalogue package - moving to staging"
		printf "Detected Catalogue Package\nMoving archive to 'MUOS/package/catalogue'\n"
		if ! mkdir -p "$MUOS_STORE_DIR/package/catalogue" || ! mv "$ARCHIVE" "$MUOS_STORE_DIR/package/catalogue/"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Failed to move catalogue package to staging"
			printf "\nFailed to Move Catalogue Package\n"
			ALL_DONE 1
		fi
		;;
	*.muxcfg)
		LOG_INFO "$0" 0 "EXTRACT" "Detected RetroArch config package - moving to staging"
		printf "Detected RetroArch Configuration Package\nMoving archive to 'MUOS/package/config'\n"
		if ! mkdir -p "$MUOS_STORE_DIR/package/config" || ! mv "$ARCHIVE" "$MUOS_STORE_DIR/package/config/"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Failed to move RetroArch configuration package to staging"
			printf "\nFailed to Move RetroArch Configuration Package\n"
			ALL_DONE 1
		fi
		;;
	*.muxalt)
		LOG_INFO "$0" 0 "EXTRACT" "Detected theme alternative archive (.muxalt)"
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		ACTIVE="$(GET_VAR "config" "theme/active")"
		if ! EXTRACT_ARCHIVE "Theme Alternative" "$ARCHIVE" "$MUOS_STORE_DIR/theme/$ACTIVE"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Theme alternative extraction failed"
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi

		if ! UPDATE_BOOTLOGO; then
			LOG_WARN "$0" 0 "EXTRACT" "Failed to update bootlogo after theme alternative extraction"
		fi
		;;
	*.muxapp)
		LOG_INFO "$0" 0 "EXTRACT" "Detected application archive (.muxapp)"
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		if ! EXTRACT_ARCHIVE "Application" "$ARCHIVE" "$MUOS_STORE_DIR/application"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Application extraction failed"
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi
		;;
	*.muxupd)
		LOG_INFO "$0" 0 "EXTRACT" "Detected system update archive (.muxupd)"
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		if ! EXTRACT_ARCHIVE "System Update" "$ARCHIVE" "/"; then
			LOG_ERROR "$0" 0 "EXTRACT" "System update extraction failed"
			printf "\nExtraction Failed...\n"
			ALL_DONE 1
		fi
		;;
	*.muxzip)
		LOG_INFO "$0" 0 "EXTRACT" "Detected multi-section archive (.muxzip)"
		SAFE_ARCHIVE "$ARCHIVE" || ALL_DONE 1

		printf "Scanning Archive Directories...\n"
		if ! TOP_LEVEL="$(GET_TOP_LEVEL_DIRS "$ARCHIVE")"; then
			LOG_ERROR "$0" 0 "EXTRACT" "Failed to scan archive directories"
			printf "\nFailed to Scan Archive Directories\n"
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
				printf "\nSkipping unsupported archive: %s\n\n" "$TOP"
				continue
			fi

			# shellcheck disable=SC1090
			. "$EXTRACTOR" || {
				printf "\n\nInvalid extractor for: %s\nExtractor not executable or cannot be sourced\n\n" "$TOP"
				continue
			}

			if ! command -v ARC_EXTRACT >/dev/null 2>&1; then
				printf "\n\nInvalid extractor for: %s\nMissing 'ARC_EXTRACT' function\n\n" "$TOP"
				ARC_UNSET
				continue
			fi

			ARC_EXTRACT || {
				printf "\n\nInvalid extractor for: %s\nCannot source 'ARC_EXTRACT' function\n\n" "$TOP"
				ARC_UNSET
				continue
			}

			if command -v ARC_EXTRACT_PRE >/dev/null 2>&1; then
				if ! ARC_EXTRACT_PRE; then
					printf "\nPre-extract hook failed for: %s — skipping\n" "$TOP"
					ARC_UNSET
					continue
				fi
			fi

			if [ -z "${DEST:-}" ] || [ -z "${LABEL:-}" ]; then
				printf "\n\nInvalid extractor for: %s\nMissing 'DEST' or 'LABEL' variables\n\n" "$TOP"
				ARC_UNSET
				continue
			fi

			REQ="$(GET_ARCHIVE_BYTES "$ARCHIVE" "$TOP/")"
			! CHECK_SPACE_FOR_DEST "$REQ" "$TOP" && ALL_DONE 1

			printf "\nExtracting '%s' to '%s'\n" "$LABEL" "$DEST"
			if EXTRACT_ARCHIVE "$LABEL" "$ARCHIVE" "$DEST" "$PATTERN"; then
				LOG_SUCCESS "$0" 0 "EXTRACT" "$(printf "Extracted '%s' to '%s'" "$LABEL" "$DEST")"
				printf "Extracted '%s' successfully\n" "$LABEL"
				ARC_STATUS=0
			else
				LOG_ERROR "$0" 0 "EXTRACT" "$(printf "Failed to extract '%s'" "$LABEL")"
				printf "Failed to extract '%s'\n" "$LABEL"
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
				printf "\nControl Initialisation Failed...\n"
				ALL_DONE 1
			}
		fi
		;;
	*)
		LOG_WARN "$0" 0 "EXTRACT" "$(printf "No extraction method for: '%s'" "$ARCHIVE_NAME")"
		printf "\nNo Extraction Method '%s'\n" "$ARCHIVE_NAME"
		;;
esac

LOG_DEBUG "$0" 0 "EXTRACT" "Correcting permissions under /opt/muos"
printf "Correcting Permissions...\n"
if ! chmod -R 755 /opt/muos; then
	LOG_WARN "$0" 0 "EXTRACT" "Failed to correct permissions under /opt/muos"
	printf "Permission Correction Failed...\n"
fi

# Only allow update archives to run the update script!
case "$ARCHIVE_NAME" in
	*.muxupd)
		UPDATE_SCRIPT=/opt/update.sh
		if [ -s "$UPDATE_SCRIPT" ]; then
			LOG_INFO "$0" 0 "EXTRACT" "$(printf "Running update script: '%s'" "$UPDATE_SCRIPT")"
			printf "Running Update Script...\n"
			chmod 755 "$UPDATE_SCRIPT"
			if ! "$UPDATE_SCRIPT"; then
				LOG_ERROR "$0" 0 "EXTRACT" "Update script failed"
				printf "Update Script Failed...\n"
				rm -f "$UPDATE_SCRIPT"
				ALL_DONE 1
			fi
			rm -f "$UPDATE_SCRIPT"
		fi
		;;
esac

if ! mkdir -p "/opt/muos/update/installed" || ! : >"/opt/muos/update/installed/$ARCHIVE_NAME.done"; then
	LOG_ERROR "$0" 0 "EXTRACT" "Failed to mark archive as installed"
	printf "Failed to Mark Archive as Installed...\n"
	ALL_DONE 1
fi

LOG_SUCCESS "$0" 0 "EXTRACT" "$(printf "Marked '%s' as installed" "$ARCHIVE_NAME")"
ALL_DONE 0
