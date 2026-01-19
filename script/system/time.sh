#!/bin/sh

. /opt/muos/script/var/func.sh

TV_FILE="/run/muos/time.valid"
[ -f "$TV_FILE" ] && exit 0

LOG_INFO "$0" 0 "TIME" "Issuing chrony burst"
/opt/muos/bin/chronyc burst 4/4 >/dev/null 2>&1 &

while :; do
	if chronyc tracking 2>/dev/null | \
		awk '/System time/ {
			gsub("seconds","",$4);
			if ($4 < 0) $4 = -$4;
			exit ($4 <= 60) ? 0 : 1
		}'
	then
		: >"$TV_FILE"
		LOG_SUCCESS "$0" 0 "TIME" "System time synchronised within 60 seconds"
		exit 0
	fi

	sleep 0.5
done
