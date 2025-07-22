#!/bin/sh

. /opt/muos/script/var/func.sh

# Disable the idle power management on the 8821cs kernel module.
# Thanks to johnnyonflame for finding this!
case "$(GET_VAR "device" "board/name")" in
	rg*) echo 0 >/sys/module/8821cs/parameters/rtw_power_mgnt ;;
	*) ;;
esac

DNS_SERVER=$(sed -n 's/^nameserver[[:space:]]\+//p' /etc/resolv.conf | head -n 1)

if [ -z "$DNS_SERVER" ]; then
	printf "No DNS server found in /etc/resolv.conf\n"
	exit 1
fi

FALLBACK_IP="8.8.8.8"

while :; do
	if ! ping -c 1 -s 8 "$DNS_SERVER" >/dev/null 2>&1; then
		if ! ping -c 1 -s 8 "$FALLBACK_IP" >/dev/null 2>&1; then
			printf "Network failure detected. Disconnecting...\n"
			/opt/muos/script/system/network.sh disconnect
			if [ "$(GET_VAR "config" "network/monitor")" -eq 1 ]; then
				printf "Trying to reconnect to network...\n"
				/opt/muos/script/system/network.sh connect
			fi
		fi
	fi
	/opt/muos/bin/toybox sleep 60
done &
