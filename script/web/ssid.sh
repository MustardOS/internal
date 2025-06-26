#!/bin/sh

. /opt/muos/script/var/func.sh

IFCE=$(GET_VAR "device" "network/iface")
NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

HEX_ESCAPE() {
	while IFS= read -r line; do
		printf "%b\n" "$line"
	done
}

LOG_INFO "$0" 0 "SSID-SCAN" "$(printf "Setting '%s' device up" "$IFCE")"
ip link set dev "$IFCE" up

LOG_INFO "$0" 0 "SSID-SCAN" "Scanning for networks..."
timeout 15 iw dev "$IFCE" scan |
	grep "SSID:" |
	sed 's/^[[:space:]]*SSID: //' |
	grep -v '^\\x00' |
	sort -u |
	HEX_ESCAPE >"$NET_SCAN"

[ ! -s "$NET_SCAN" ] && printf "[!]" >"$NET_SCAN"
