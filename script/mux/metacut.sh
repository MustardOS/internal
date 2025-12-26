#!/bin/sh

if [ $# -ne 1 ]; then
	echo "Usage: $0 <input>"
	exit 1
fi

. /opt/muos/script/var/func.sh

# Define base directory and resolution
ACTIVE="$(GET_VAR "config" "theme/active")"
ACTIVE_DIR="$MUOS_STORE_DIR/theme/$ACTIVE"
DEVICE_RES="$(GET_VAR "device" "mux/width")x$(GET_VAR "device" "mux/height")"

# Determine SCHEME based on file availability
DIR="$ACTIVE_DIR/$DEVICE_RES"
[ ! -d "$DIR" ] && DIR="$ACTIVE_DIR"

SCHEME="$DIR/scheme/muxplore.txt"
[ ! -f "$SCHEME" ] && SCHEME="$DIR/scheme/default.txt"

METACUT=$(PARSE_INI "$SCHEME" "meta" "META_CUT")
[ -z "$METACUT" ] && METACUT=40

# The discovery of fold really helps here!
# Except for UTF-8 and CJK which I'm not really sure
# how to really get around... super annoying!
tr '\n\t' '  ' <"$1"  | tr -s ' ' | fold -s -w "$METACUT"
