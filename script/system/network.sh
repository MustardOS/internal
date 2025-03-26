#!/bin/sh

. /opt/muos/script/var/func.sh

ADDR=$(GET_VAR "global" "network/address")
SUBN=$(GET_VAR "global" "network/subnet")
SSID=$(GET_VAR "global" "network/ssid")
GATE=$(GET_VAR "global" "network/gateway")
TYPE=$(GET_VAR "global" "network/type")

IFCE=$(GET_VAR "device" "network/iface")
DRIV=$(GET_VAR "device" "network/type")

RETRIES="${RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-3}"

WPA_FILE="/etc/wpa_supplicant.conf"
CURRENT_IP="/opt/muos/config/address.txt"
: >"$CURRENT_IP"

killall -q dhcpcd wpa_supplicant

TRY_CONNECT() {
	[ -z "$SSID" ] && return 1

	ip link set dev "$IFCE" up

	if [ "$IFCE" = "wlan0" ]; then
		wpa_supplicant -B -i "$IFCE" -c "$WPA_FILE" -D "$DRIV"
		sleep 1
	fi

	if [ "$TYPE" -eq 0 ]; then
		rm -rf /var/db/dhcpcd/*
		dhcpcd -w -q "$IFCE" || {
			IP="0.0.0.0"
			return 1
		}
	else
		ip addr add "$ADDR"/"$SUBN" dev "$IFCE"
		ip route | grep -q "default via $GATE" || ip route add default via "$GATE"
	fi

	IP=$(ip -4 a show dev "$IFCE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p')

	if ! ping -q -c1 -w2 1.1.1.1 >/dev/null 2>&1; then
		IP="0.0.0.0"
		return 1
	fi

	TMP_FILE=$(mktemp)
	echo "${IP:-0.0.0.0}" >"$TMP_FILE"
	mv "$TMP_FILE" "$CURRENT_IP"

	return 0
}

case "$1" in
	disconnect)
		: >"$WPA_FILE"
		rm -rf /var/db/dhcpcd/*
		ip link set dev "$IFCE" down
		/opt/muos/script/web/service.sh stopall &
		;;

	connect)
		while [ "$RETRIES" -gt 0 ]; do
			TRY_CONNECT && break
			RETRIES=$((RETRIES - 1))
			sleep "$RETRY_DELAY"
		done
		/opt/muos/script/web/service.sh &
		;;
esac
