#!/bin/sh

. /opt/muos/script/var/func.sh

CURRENT_IP="/opt/muos/config/address.txt"
: >"$CURRENT_IP"

killall -q dhcpcd wpa_supplicant

TRY_CONNECT() {
	[ -z "$(GET_VAR "global" "network/ssid")" ] && exit

	if [ "$(GET_VAR "device" "network/iface")" = "wlan0" ]; then
		wpa_supplicant -dd -B -i "$(GET_VAR "device" "network/iface")" -c /etc/wpa_supplicant.conf -D "$(GET_VAR "device" "network/type")"
	fi

	if [ "$(GET_VAR "global" "network/type")" -eq 0 ]; then
		rm -rf "/var/db/dhcpcd/*"
		dhcpcd -n
		dhcpcd -w -q "$(GET_VAR "device" "network/iface")" &
	else
		ip addr add "$(GET_VAR "global" "network/address")"/"$(GET_VAR "global" "network/subnet")" dev "$(GET_VAR "device" "network/iface")"
		ip link set dev "$(GET_VAR "device" "network/iface")" up
		ip route add default via "$(GET_VAR "global" "network/gateway")"
	fi

	OIP=0
	while [ "$(cat "$CURRENT_IP")" = "" ]; do
		OIP=$((OIP + 1))
		ip -4 a show dev "$(GET_VAR "device" "network/iface")" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p' | tr -d '\n' >"$CURRENT_IP"
		sleep 1
		if [ $OIP -eq 30 ]; then
			echo "0.0.0.0" | tr -d '\n' >"$CURRENT_IP"
			break
		fi
	done

	[ "$(cat "$CURRENT_IP")" = "0.0.0.0" ] && exit
}

case "$1" in
	disconnect)
		: >/etc/wpa_supplicant.conf
		rm -rf "/var/db/dhcpcd/*"
		/opt/muos/script/web/service.sh stopall &
		;;
	connect)
		TRY_CONNECT
		/opt/muos/script/web/service.sh &
		;;
esac
