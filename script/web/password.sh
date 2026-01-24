#!/bin/sh

. /opt/muos/script/var/func.sh

SSID="$(GET_VAR "config" "network/ssid")"
PASS="$(GET_VAR "config" "network/pass")"
HIDDEN="$(GET_VAR "config" "network/hidden")"

case ${#PASS} in
	64)
		printf "network={\n\tssid=\"%s\"\n\tscan_ssid=%s\n\tpsk=%s\n}" "$SSID" "$HIDDEN" "$PASS" >"$WPA_CONFIG"
		;;
	0)
		printf "network={\n\tssid=\"%s\"\n\tscan_ssid=%s\n\tkey_mgmt=NONE\n}" "$SSID" "$HIDDEN" >"$WPA_CONFIG"
		;;
	*)
		wpa_passphrase "$SSID" "$PASS" | sed -n '/^[ \t]*psk=/s/^[ \t]*psk=//p' >"/opt/muos/config/network/pass"
		wpa_passphrase "$SSID" "$PASS" >"$WPA_CONFIG"
		sed -i '3d' "$WPA_CONFIG"
		;;
esac
