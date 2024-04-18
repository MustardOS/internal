#!/bin/sh
# shellcheck disable=1090,2002

MUOSBOOT_LOG=/mnt/mmc/MUOS/log/network.txt

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")

CIP=/opt/muos/config/address.txt

LOGGER() {
VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	_MESSAGE=$1
	echo "=== ${CURRENT_DATE} === $_MESSAGE" >> "$MUOSBOOT_LOG"
fi
}

NET_ENABLED=$(parse_ini "$CONFIG" "network" "enabled")
NET_INTERFACE=$(parse_ini "$CONFIG" "network" "interface")
NET_TYPE=$(parse_ini "$CONFIG" "network" "type")
NET_ADDRESS=$(parse_ini "$CONFIG" "network" "address")
NET_SUBNET=$(parse_ini "$CONFIG" "network" "subnet")
NET_GATEWAY=$(parse_ini "$CONFIG" "network" "gateway")
NET_DNS=$(parse_ini "$CONFIG" "network" "dns")

LOGGER "Bringing Wi-Fi Interface Down"
killall wpa_supplicant
killall dhcpcd
ip link set "$NET_INTERFACE" down

LOGGER "Killing running web services"
killall dropbear
killall sftpgo
killall gotty
killall syncthing

echo "0.0.0.0" | tr -d '\n' > "$CIP"

LOGGER "Fixing Nameserver"
echo "nameserver $NET_DNS" > /etc/resolv.conf

if [ "$NET_ENABLED" -eq 0 ]; then
	rmmod /lib/modules/4.9.170/kernel/drivers/net/wireless/rtl8821cs/8821cs.ko
	exit
fi

if ! lsmod | grep -wq 8821cs; then
    LOGGER "Loading 'rtl8821cs' Kernel Module"
    insmod /lib/modules/4.9.170/kernel/drivers/net/wireless/rtl8821cs/8821cs.ko
    while ! dmesg | grep -wq "$NET_INTERFACE"; do
        sleep 1
    done
    LOGGER "Wi-Fi Module Loaded"
fi

LOGGER "Setting up Wi-Fi Interface"
rfkill unblock all
ip link set "$NET_INTERFACE" up
iw dev "$NET_INTERFACE" set power_save off

LOGGER "Configuring WPA Supplicant"
wpa_supplicant -dd -B -i"$NET_INTERFACE" -c /etc/wpa_supplicant.conf -D nl80211

if [ "$NET_TYPE" -eq 0 ]; then
	LOGGER "Clearing DHCP leases"
	rm -rf "/var/db/dhcpcd/*"
	LOGGER "Configuring Network using DHCP"
	dhcpcd -n
	dhcpcd -w -q "$NET_INTERFACE" &
else
	LOGGER "Configuring Network using Static"
	ip addr add "$NET_ADDRESS"/"$NET_SUBNET" dev "$NET_INTERFACE"
	ip link set dev "$NET_INTERFACE" up
	ip route add default via "$NET_GATEWAY"
fi

OIP=0
while [ "$(cat "$CIP")" = "0.0.0.0" ] || [ "$(cat "$CIP")" = "" ]; do
	LOGGER "Waiting for IP Address"
	OIP=$((OIP + 1))
	ip -4 a show dev "$NET_INTERFACE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p' | tr -d '\n' > "$CIP"
	sleep 1
	if [ $OIP -eq 30 ]; then
		echo "0.0.0.0" | tr -d '\n' > "$CIP"
		break
	fi
done

if [ "$(cat "$CIP")" = "0.0.0.0" ]; then
	exit
fi

LOGGER "Running Web Service Script"
/opt/muos/script/web/service.sh

