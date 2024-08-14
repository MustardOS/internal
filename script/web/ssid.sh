#!/bin/sh

. /opt/muos/script/var/func.sh

if ! lsmod | grep -wq "$(GET_VAR "device" "network/name")"; then
	rmmod "$(GET_VAR "device" "network/module")"
	sleep 1
	modprobe --force-modversion "$(GET_VAR "device" "network/module")"
	while [ ! -d "/sys/class/net/$(GET_VAR "device" "network/iface")" ]; do
		sleep 1
	done
fi

rfkill unblock all
ip link set "$(GET_VAR "device" "network/iface")" up
iw dev "$(GET_VAR "device" "network/iface")" set power_save off

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

[ ! -s "$NET_SCAN" ] && echo "0" >"$NET_SCAN"
