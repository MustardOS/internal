#!/bin/sh

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <input>"
	exit 1
fi

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/global/storage.sh

SCHEME="$GC_STO_THEME/MUOS/theme/active/scheme/default.txt"

METACUT=$(PARSE_INI "$SCHEME" "meta" "META_CUT")

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
