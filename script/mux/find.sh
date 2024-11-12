#!/bin/sh

USAGE() {
	echo "Usage: $0 <directory> <search term>"
	exit 1
}

if [ "$#" -ne 2 ]; then
	USAGE "$0"
fi

. /opt/muos/script/var/func.sh

MUXRESULT="/tmp/muxresult"

SDIR="$1"
STERM="$2"

[ -d "$MUXRESULT" ] && rm -rf "$MUXRESULT"

/opt/muos/bin/rg --files "$SDIR" 2>&1 |
	/opt/muos/bin/rg --pcre2 -i "\/(?!.*\/).*$STERM" |
	sed "s|^$SDIR/||" |
	while IFS= read -r RESULT; do
		mkdir -p "$MUXRESULT/$(dirname "$RESULT")"
		touch "$MUXRESULT/$RESULT"
	done
