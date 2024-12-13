#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 <input>"
	exit 1
fi

. /opt/muos/script/var/func.sh

# Define base directory and resolution
ACTIVE_DIR="/run/muos/storage/theme/active"
DEVICE_RES="$(GET_VAR "device" "mux/width")x$(GET_VAR "device" "mux/height")"

# Determine SCHEME based on file availability
DIR="$ACTIVE_DIR/$DEVICE_RES"
[ ! -d "$DIR" ] && DIR="$ACTIVE_DIR"

SCHEME="$DIR/scheme/muxplore.txt"
[ ! -f "$SCHEME" ] && SCHEME="$DIR/scheme/default.txt"

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
