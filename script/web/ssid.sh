#!/bin/sh

. /opt/muos/script/var/func.sh

NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

{
	iw dev "$(GET_VAR "device" "network/iface")" scan |
		grep "SSID:" |
		awk '{gsub(/^ +| +$/, "", $0); print substr($0, 8)}' |
		sort -u |
		grep -v '^\\x00' |
		grep -v '^$' |
		grep -v '[^[:print:]]'
} >"$NET_SCAN" &

SCAN_TIMEOUT=0
while [ $SCAN_TIMEOUT -lt 15 ] && [ ! -s "$NET_SCAN" ]; do
	sleep 1
	SCAN_TIMEOUT=$((SCAN_TIMEOUT + 1))
done

[ ! -s "$NET_SCAN" ] && printf "[!]" >"$NET_SCAN"
