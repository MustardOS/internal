#!/bin/sh

. /opt/muos/script/var/func.sh

IFCE="$(GET_VAR "device" "network/iface_active")"
[ -n "$IFCE" ] || IFCE="$(GET_VAR "device" "network/iface")"
NET_SCAN="/tmp/net_scan"
rm -f "$NET_SCAN"

HEX_ESCAPE() {
	while IFS= read -r line; do
		printf "%b\n" "$line"
	done
}

# Load network module for devices with USB WiFi adapters
case "$(GET_VAR "device" "board/name")" in
	rg*) [ ! -d "/sys/bus/mmc/devices/mmc2:0001" ] && /opt/muos/script/device/network.sh load ;;
	rk*) /opt/muos/script/device/network.sh load ;;
	tui*) /opt/muos/script/device/network.sh load ;;
	*) ;;
esac

LOG_INFO "$0" 0 "SSID-SCAN" "$(printf "Setting '%s' device up" "$IFCE")"
ip link set dev "$IFCE" up

LOG_INFO "$0" 0 "SSID-SCAN" "Scanning for networks..."

# Check if we need to use wireless extensions (rk* devices with staging driver)
BOARD_NAME=$(GET_VAR "device" "board/name")
case "$BOARD_NAME" in
	rk*)
		# Use wireless extensions (iwlist) for staging r8188eu driver
		timeout 15 iwlist "$IFCE" scan 2>/dev/null |
			grep "ESSID:" |
			sed 's/^[[:space:]]*ESSID:"//' |
			sed 's/"$//' |
			grep -v '^$' |
			sort -u |
			HEX_ESCAPE >"$NET_SCAN"
		;;
	*)
		# Use nl80211 (iw) for modern drivers
		timeout 15 iw dev "$IFCE" scan 2>/dev/null |
			grep "SSID:" |
			sed 's/^[[:space:]]*SSID: //' |
			grep -v '^\\x00' |
			sort -u |
			HEX_ESCAPE >"$NET_SCAN"
		;;
esac

[ ! -s "$NET_SCAN" ] && printf "[!]" >"$NET_SCAN"
