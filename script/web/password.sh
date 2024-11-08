#!/bin/sh

. /opt/muos/script/var/func.sh

SSID="$(GET_VAR "global" "network/ssid")"
PASS="$(GET_VAR "global" "network/pass")"

WPA_CONFIG=/etc/wpa_supplicant.conf

case ${#PASS} in
	64)
		printf "network={\n\tssid=\"%s\"\n\tpsk=%s\n}" "$SSID" "$PASS" >"$WPA_CONFIG"
		;;
	0)
		printf "network={\n\tssid=\"%s\"\n\tkey_mgmt=NONE\n}" "$SSID" >"$WPA_CONFIG"
		;;
	*)
		wpa_passphrase "$SSID" "$PASS" | sed -n '/^[ \t]*psk=/s/^[ \t]*psk=//p' >"/run/muos/global/network/pass"
		wpa_passphrase "$SSID" "$PASS" >"$WPA_CONFIG"
		sed -i '3d' "$WPA_CONFIG"
		;;
esac
