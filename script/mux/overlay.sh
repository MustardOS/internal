#!/bin/sh

. /opt/muos/script/var/func.sh

OVERLAY_NOP="/run/muos/overlay.disable"
if [ -e "$OVERLAY_NOP" ]; then
	rm -f "$OVERLAY_NOP"
else
	: >"$OVERLAY_NOP"
fi

exit 0
