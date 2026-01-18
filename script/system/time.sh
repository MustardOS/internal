#!/bin/sh

. /opt/muos/script/var/func.sh

TV_FILE="/run/muos/time.valid"
[ -f "$TV_FILE" ] && exit 0

LOG_INFO "$0" 0 "TIME" "Issuing chrony burst"
/opt/muos/bin/chronyc burst 4/4 >/dev/null 2>&1 &

while :; do
	if /opt/muos/bin/chronyc tracking 2>/dev/null | grep -q "Leap status.*Normal"; then
		: >"$TV_FILE"
		LOG_SUCCESS "$0" 0 "TIME" "System time synchronised"
		exit 0
	fi

	sleep 3
done
