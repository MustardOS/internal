#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <input>"
	exit 1
fi

. /opt/muos/script/system/parse.sh
SCHEME=/opt/muos/theme/scheme/default.txt

METACUT=$(parse_ini "$SCHEME" "meta" "META_CUT")

if [ -z "$METACUT" ]; then
	METACUT=40
fi

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

