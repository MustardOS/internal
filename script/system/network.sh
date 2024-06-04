#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

STORE_ROM=$(parse_ini "$DEVICE_CONFIG" "storage.rom" "mount")

CURRENT_DATE=$(date +"%Y_%m_%d__%H_%M_%S")
MUOSBOOT_LOG="$STORE_ROM/MUOS/log/network.txt"

CURRENT_IP="/opt/muos/config/address.txt"

LOGGER() {
VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	_MESSAGE=$1
	echo "=== ${CURRENT_DATE} === $_MESSAGE" >> "$MUOSBOOT_LOG"
fi
}

DEV_MODULE=$(parse_ini "$DEVICE_CONFIG" "network" "module")
DEV_NAME=$(parse_ini "$DEVICE_CONFIG" "network" "name")
DEV_TYPE=$(parse_ini "$DEVICE_CONFIG" "network" "type")

NET_ENABLED=$(parse_ini "$CONFIG" "network" "enabled")
NET_INTERFACE=$(parse_ini "$DEVICE_CONFIG" "network" "iface")
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
killall sshd
killall sftpgo
killall gotty
killall syncthing

echo "0.0.0.0" | tr -d '\n' > "$CURRENT_IP"

LOGGER "Fixing Nameserver"
echo "nameserver $NET_DNS" > /etc/resolv.conf

if [ "$NET_ENABLED" -eq 0 ]; then
	rmmod "$DEV_MODULE"
	exit
fi

if ! lsmod | grep -wq "$DEV_NAME"; then
    LOGGER "Loading '$DEV_NAME' Kernel Module"
    insmod "$DEV_MODULE"
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
wpa_supplicant -dd -B -i "$NET_INTERFACE" -c /etc/wpa_supplicant.conf -D "$DEV_TYPE"

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
while [ "$(cat "$CURRENT_IP")" = "0.0.0.0" ] || [ "$(cat "$CURRENT_IP")" = "" ]; do
	LOGGER "Waiting for IP Address"
	OIP=$((OIP + 1))
	ip -4 a show dev "$NET_INTERFACE" | sed -nE 's/.*inet ([0-9.]+)\/.*/\1/p' | tr -d '\n' > "$CURRENT_IP"
	sleep 1
	if [ $OIP -eq 30 ]; then
		echo "0.0.0.0" | tr -d '\n' > "$CURRENT_IP"
		break
	fi
done

if [ "$(cat "$CURRENT_IP")" = "0.0.0.0" ]; then
	exit
fi

LOGGER "Starting DNS Ping"
/opt/muos/script/web/ping.sh

LOGGER "Running Web Service Script"
/opt/muos/script/web/service.sh

