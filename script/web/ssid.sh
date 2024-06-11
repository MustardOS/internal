#!/bin/sh

. /opt/muos/script/system/parse.sh

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

DEV_MODULE=$(parse_ini "$DEVICE_CONFIG" "network" "module")
DEV_NAME=$(parse_ini "$DEVICE_CONFIG" "network" "name")

NET_INTERFACE=$(parse_ini "$DEVICE_CONFIG" "network" "iface")

if ! lsmod | grep -wq "$DEV_NAME"; then
    rmmod "$DEV_MODULE"
    sleep 1
    LOGGER "Loading '$DEV_NAME' Kernel Module"
    modprobe --force-modversion "$DEV_MODULE"
    while [ ! -d "/sys/class/net/$NET_INTERFACE" ]; do
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

