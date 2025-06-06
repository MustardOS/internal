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

while :; do
	ping -c 1 -s 8 "$DNS_SERVER" >/dev/null 2>&1
	/opt/muos/bin/toybox sleep 60
done &
