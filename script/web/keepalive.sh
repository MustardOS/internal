#!/bin/sh

. /opt/muos/script/var/config.sh

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
			/opt/muos/script/init/async/S02network.sh disconnect
			if [ "$(GET_VAR "config" "settings/network/monitor")" -eq 1 ]; then
				printf "Trying to reconnect to network...\n"
				/opt/muos/script/init/async/S02network.sh start
			fi
		fi
	fi
	sleep 60
done &
