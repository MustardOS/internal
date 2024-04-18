#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

NET_INTERFACE=$(parse_ini "$CONFIG" "network" "interface")

if ! lsmod | grep -wq 8821cs; then
    LOGGER "Loading 'rtl8821cs' Kernel Module"
    insmod /lib/modules/4.9.170/kernel/drivers/net/wireless/rtl8821cs/8821cs.ko
    while ! dmesg | grep -wq "$NET_INTERFACE"; do
        sleep 1
    done
    LOGGER "Wi-Fi Module Loaded"
fi

rfkill unblock all
ip link set "$NET_INTERFACE" up
iw dev "$NET_INTERFACE" set power_save off

NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

{
iw dev "$NET_INTERFACE" scan |
	grep "SSID:" |
	awk '{gsub(/^ +| +$/, "", $0); print substr($0, 8)}' |
	sort -u |
	grep -v '^\\x00' |
	grep -v '^$' |
	grep -v '[^[:print:]]'
} > "$NET_SCAN" &

SCAN_TIMEOUT=0
while [ $SCAN_TIMEOUT -lt 15 ] && [ ! -s "$NET_SCAN" ]; do
	sleep 1
	SCAN_TIMEOUT=$((SCAN_TIMEOUT+1))
done

[ ! -s "$NET_SCAN" ] && echo "0" > "$NET_SCAN"

