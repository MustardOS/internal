#!/bin/sh

DNS_SERVER=$(sed -n 's/^nameserver[[:space:]]\+//p' /etc/resolv.conf | head -n 1)

if [ -z "$DNS_SERVER" ]; then
    printf "No DNS server found in /etc/resolv.conf\n"
    exit 1
fi

while :; do
    ping -c 1 -s 8 "$DNS_SERVER" >/dev/null 2>&1
    /opt/muos/bin/toybox sleep 60
done &
