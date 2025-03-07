#!/bin/sh

. /opt/muos/script/var/func.sh

NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

HEX_ESCAPE() {
	while IFS= read -r line; do
		printf "%b\n" "$line"
	done
}

{
	iw dev "$(GET_VAR "device" "network/iface")" scan |
		grep "SSID:" |
		sed 's/^[[:space:]]*SSID: //' |
		grep -v '^\\x00' |
		sort -u |
		HEX_ESCAPE
} >"$NET_SCAN" &

SCAN_TIMEOUT=0
while [ $SCAN_TIMEOUT -lt 15 ] && [ ! -s "$NET_SCAN" ]; do
	sleep 1
	SCAN_TIMEOUT=$((SCAN_TIMEOUT + 1))
done

[ ! -s "$NET_SCAN" ] && printf "[!]" >"$NET_SCAN"
