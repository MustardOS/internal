#!/bin/sh

. /opt/muos/script/var/func.sh

if [ -e "$OVERLAY_NOP" ]; then
	LOG_INFO "$0" 0 "OVERLAY" "$(printf "Enabling overlay - removing '%s'" "$OVERLAY_NOP")"
	rm -f "$OVERLAY_NOP"
else
	LOG_INFO "$0" 0 "OVERLAY" "$(printf "Disabling overlay - creating '%s'" "$OVERLAY_NOP")"
	: >"$OVERLAY_NOP"
fi

exit 0
