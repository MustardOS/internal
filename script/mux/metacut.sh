#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 <input>"
	exit 1
fi

. /opt/muos/script/var/func.sh

# Define the base directory for the theme schemes
SCHEME_DIR="/run/muos/storage/theme/active/scheme"

# Set SCHEME to muxplore.txt if it exists, otherwise revert to default.txt
if [ -f "$SCHEME_DIR/muxplore.txt" ]; then
	SCHEME="$SCHEME_DIR/muxplore.txt"
else
	SCHEME="$SCHEME_DIR/default.txt"
fi

METACUT=$(PARSE_INI "$SCHEME" "meta" "META_CUT")
[ -z "$METACUT" ] && METACUT=40

awk -v meta_cut="$METACUT" '
BEGIN { RS = " "; ORS = ""; }
{
	if (length(line $0) > meta_cut) {
		print line "\n";
		line = $0 " ";
	} else {
		line = line $0 " ";
	}
}

END {
	if (length(line) > meta_cut) {
		print substr(line, 1, meta_cut) "\n" substr(line, meta_cut + 1) "\n";
	} else {
		print line "\n";
	}
}' "$1"
