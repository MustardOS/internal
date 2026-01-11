#!/bin/sh

. /opt/muos/script/var/func.sh

if [ -e "$OVERLAY_NOP" ]; then
	rm -f "$OVERLAY_NOP"
else
	: >"$OVERLAY_NOP"
fi

exit 0
