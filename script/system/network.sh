#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/network.sh

. /opt/muos/script/var/global/network.sh

CURRENT_IP="/opt/muos/config/address.txt"

if [ "$DC_NET_INTERFACE" = "wlan0" ]; then
	killall wpa_supplicant
fi
killall dhcpcd
ip link set "$DC_NET_INTERFACE" down

killall -q sshd sftpgo gotty syncthing ntp.sh

echo "0.0.0.0" | tr -d '\n' >"$CURRENT_IP"

echo "nameserver $GC_NET_DNS" >/etc/resolv.conf

if [ "$DC_NET_INTERFACE" = "wlan0" ]; then
	if [ "$GC_NET_ENABLED" -eq 0 ]; then
		rmmod "$DC_NET_MODULE"
		exit
	fi

	if ! lsmod | grep -wq "$DC_NET_NAME"; then
		rmmod "$DC_NET_MODULE"
		sleep 1
		modprobe --force-modversion "$DC_NET_MODULE"
		while [ ! -d "/sys/class/net/$DC_NET_INTERFACE" ]; do
			sleep 1
		done
	fi
fi

rfkill unblock all
ip link set "$DC_NET_INTERFACE" up
iw dev "$DC_NET_INTERFACE" set power_save off

if [ "$DC_NET_INTERFACE" = "wlan0" ]; then
	wpa_supplicant -dd -B -i "$DC_NET_INTERFACE" -c /etc/wpa_supplicant.conf -D "$DC_NET_TYPE"
fi

if [ "$GC_NET_TYPE" -eq 0 ]; then
	rm -rf "/var/db/dhcpcd/*"
	dhcpcd -n
	dhcpcd -w -q "$DC_NET_INTERFACE" &
else
	ip addr add "$GC_NET_ADDRESS"/"$GC_NET_SUBNET" dev "$DC_NET_INTERFACE"
	ip link set dev "$DC_NET_INTERFACE" up
	ip route add default via "$GC_NET_GATEWAY"
fi

OIP=0
while [ "$(cat "$CURRENT_IP")" = "0.0.0.0" ] || [ "$(cat "$CURRENT_IP")" = "" ]; do
	OIP=$((OIP + 1))
	ip -4 a show dev "$DC_NET_INTERFACE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p' | tr -d '\n' >"$CURRENT_IP"
	sleep 1
	if [ $OIP -eq 30 ]; then
		echo "0.0.0.0" | tr -d '\n' >"$CURRENT_IP"
		break
	fi
done

if [ "$(cat "$CURRENT_IP")" = "0.0.0.0" ]; then
	exit
fi

/opt/muos/script/web/service.sh &
