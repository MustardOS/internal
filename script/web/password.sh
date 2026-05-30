#!/bin/sh

. /opt/muos/script/var/func.sh

SSID="$(GET_VAR "config" "network/ssid")"
PASS="$(GET_VAR "config" "network/pass")"
HIDDEN="$(GET_VAR "config" "network/hidden")"

SSID_WPA="$(GET_VAR "config" "network/ssid_wpa")"
[ -z "$SSID_WPA" ] && SSID_WPA=$(printf '%s' "$SSID" | sed 's/\\/\\\\/g; s/"/\\"/g')

case ${#PASS} in
	64) printf "network={\n\tssid=\"%s\"\n\tscan_ssid=%s\n\tpsk=%s\n}" "$SSID_WPA" "$HIDDEN" "$PASS" >"$WPA_CONFIG" ;;
	0) printf "network={\n\tssid=\"%s\"\n\tscan_ssid=%s\n\tkey_mgmt=NONE\n}" "$SSID_WPA" "$HIDDEN" >"$WPA_CONFIG" ;;
	*)
		WPA_TMP=$(mktemp)

		trap 'rm -f "$WPA_TMP"' EXIT INT TERM
		wpa_passphrase "$SSID" "$PASS" >"$WPA_TMP"

		# Extract the derived hex PSK and persist it (replacing the plain password)
		sed -n '/^[[:space:]]*psk=/s/^[[:space:]]*psk=//p' "$WPA_TMP" >"/opt/muos/config/network/pass"
		sed '/^[[:space:]]*#psk=/d' "$WPA_TMP" >"$WPA_CONFIG"

		rm -f "$WPA_TMP"
		;;
esac
