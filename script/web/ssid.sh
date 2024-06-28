#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/network.sh

if ! lsmod | grep -wq "$DC_NET_NAME"; then
	rmmod "$DC_NET_MODULE"
	sleep 1
	modprobe --force-modversion "$DC_NET_MODULE"
	while [ ! -d "/sys/class/net/$DC_NET_INTERFACE" ]; do
		sleep 1
	done
fi

rfkill unblock all
ip link set "$DC_NET_INTERFACE" up
iw dev "$DC_NET_INTERFACE" set power_save off

NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

{
	iw dev "$DC_NET_INTERFACE" scan |
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
