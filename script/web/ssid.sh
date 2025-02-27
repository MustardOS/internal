#!/bin/sh

. /opt/muos/script/var/func.sh

NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

{
	iw dev "$(GET_VAR "device" "network/iface")" scan |
		grep "SSID:" |
		sed 's/^[[:space:]]*SSID: //' |
		grep -v '^\\x00' |
		sed 's/\\x20/ /g' |
		sort -u
} >"$NET_SCAN" &

SCAN_TIMEOUT=0
while [ $SCAN_TIMEOUT -lt 15 ] && [ ! -s "$NET_SCAN" ]; do
	sleep 1
	SCAN_TIMEOUT=$((SCAN_TIMEOUT + 1))
done

[ ! -s "$NET_SCAN" ] && printf "[!]" >"$NET_SCAN"
