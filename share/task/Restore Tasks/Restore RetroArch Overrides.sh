#!/bin/sh
# HELP: Restore the default RetroArch overrides
# ICON: retroarch

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/zip.sh

FRONTEND stop

RA_CONF_DIR="$MUOS_SHARE_DIR/info/config"
RA_CONF_ZIP="$MUOS_SHARE_DIR/archive/ra.config.zip"

ALL_DONE() {
	unset -f MU_EXTRACT 2>/dev/null

	echo "Sync Filesystem"
	sync

	TBOX sleep 2

	FRONTEND start task
	exit "$1"
}

if [ ! -e "$RA_CONF_ZIP" ]; then
	printf "\nError: Name archive not found!\n"
	ALL_DONE 1
fi

DEST=""
LABEL=""
PATTERN="config/*"

EXTRACTOR="/opt/muos/script/archive/config.sh"
# shellcheck disable=SC1090
. "$EXTRACTOR" || {
	printf "\n\nInvalid extractor for: %s\nExtractor not executable or cannot be sourced\n\n" "$TOP"
	ALL_DONE 1
}

MU_EXTRACT || {
	printf "\n\nInvalid extractor for: %s\nCannot source 'MU_EXTRACT' function\n\n" "$TOP"
	ALL_DONE 1
}

SPACE_REQ="$(GET_ARCHIVE_BYTES "$RA_CONF_ZIP" "")"
! CHECK_SPACE_FOR_DEST "$SPACE_REQ" "$RA_CONF_DIR" && ALL_DONE 1

printf "\nExtracting '%s' to '%s'\n" "$LABEL" "$DEST"
if EXTRACT_ARCHIVE "$LABEL" "$RA_CONF_ZIP" "$DEST" "$PATTERN"; then
	printf "Extracted '%s' successfully\n" "$LABEL"
else
	printf "Failed to extract '%s'\n" "$LABEL"
fi

echo "All Done!"
ALL_DONE 0
