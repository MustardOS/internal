#!/bin/sh

SSID=$(cat "/tmp/net_ssid")
PASS=$(cat "/tmp/net_pass")

WPA_CONFIG=/etc/wpa_supplicant.conf

echo "$SSID" >"/run/muos/global/network/ssid"

if [ ${#PASS} -eq 64 ]; then
	echo "$PASS" >"/run/muos/global/network/pass"
	printf "network={\n\tssid=\"%s\"\n\tpsk=%s\n}" "$SSID" "$PASS" >"$WPA_CONFIG"
else
	wpa_passphrase "$SSID" "$PASS" | sed -n '/^[ \t]*psk=/s/^[ \t]*psk=//p' >"/run/muos/global/network/pass"
	wpa_passphrase "$SSID" "$PASS" >"$WPA_CONFIG"
	sed -i '3d' "$WPA_CONFIG"
fi

rm /tmp/net_ssid /tmp/net_pass
