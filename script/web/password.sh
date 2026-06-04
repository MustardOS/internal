#!/bin/sh

. /opt/muos/script/var/func.sh

SSID="$(GET_VAR "config" "network/ssid")"
PASS="$(GET_VAR "config" "network/pass")"

SSID_WPA="$(GET_VAR "config" "network/ssid_wpa")"
[ -z "$SSID_WPA" ] && SSID_WPA=$(printf '%s' "$SSID" | sed 's/\\/\\\\/g; s/"/\\"/g')

PROFILE_DIR="${MUOS_SHARE_DIR}/network"

APPEND_NETWORK_CFG() {
	NET_PROF_SSID="$1"
	NET_PROF_PASS="$2"
	NET_PROF_SSID_WPA="$3"
	NET_PROF_PR="$4"
	NET_PROF_TMP=

	case ${#NET_PROF_PASS} in
		64)
			printf "\nnetwork={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tpsk=%s\n\tpriority=%s\n}" \
				"$NET_PROF_SSID_WPA" "$NET_PROF_PASS" "$NET_PROF_PR" >>"$WPA_CONFIG"
			;;
		0)
			printf "\nnetwork={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tkey_mgmt=NONE\n\tpriority=%s\n}" \
				"$NET_PROF_SSID_WPA" "$NET_PROF_PR" >>"$WPA_CONFIG"
			;;
		*)
			NET_PROF_TMP=$(mktemp)
			wpa_passphrase "$NET_PROF_SSID" "$NET_PROF_PASS" >"$NET_PROF_TMP"

			NET_PROF_PSK=$(sed -n '/^[[:space:]]*psk=/s/^[[:space:]]*psk=//p' "$NET_PROF_TMP")
			rm -f "$NET_PROF_TMP"

			printf "\nnetwork={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tpsk=%s\n\tpriority=%s\n}" \
				"$NET_PROF_SSID_WPA" "$NET_PROF_PSK" "$NET_PROF_PR" >>"$WPA_CONFIG"
			;;
	esac
}

case ${#PASS} in
	64) printf "network={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tpsk=%s\n\tpriority=10\n}" "$SSID_WPA" "$PASS" >"$WPA_CONFIG" ;;
	0) printf "network={\n\tssid=\"%s\"\n\tscan_ssid=1\n\tkey_mgmt=NONE\n\tpriority=10\n}" "$SSID_WPA" >"$WPA_CONFIG" ;;
	*)
		WPA_TMP=$(mktemp)

		trap 'rm -f "$WPA_TMP"' EXIT INT TERM
		wpa_passphrase "$SSID" "$PASS" >"$WPA_TMP"

		# Extract the derived hex PSK and persist it (replacing the plain password)
		sed -n '/^[[:space:]]*psk=/s/^[[:space:]]*psk=//p' "$WPA_TMP" >"/opt/muos/config/network/pass"
		awk '/^network=/ { print; print "\tpriority=10"; next }
		     /ssid=/     { print; print "\tscan_ssid=1"; next }
		     !/^[[:space:]]*#psk=/' "$WPA_TMP" >"$WPA_CONFIG"

		rm -f "$WPA_TMP"
		;;
esac

[ -d "$PROFILE_DIR" ] || exit 0

for NET_PROF in "$PROFILE_DIR"/*.ini; do
	[ -f "$NET_PROF" ] || continue

	NET_PROF_AC=$(PARSE_INI "$NET_PROF" "network" "autoconnect")
	[ "${NET_PROF_AC:-1}" -eq 1 ] || continue

	NET_PROF_SSID=$(PARSE_INI "$NET_PROF" "network" "ssid")
	[ -z "$NET_PROF_SSID" ] && continue
	[ "$NET_PROF_SSID" = "$SSID" ] && continue

	NET_PROF_PASS=$(PARSE_INI "$NET_PROF" "network" "pass")
	NET_PROF_PR=$(PARSE_INI "$NET_PROF" "network" "priority")
	NET_PROF_SSID_WPA=$(printf '%s' "$NET_PROF_SSID" | sed 's/\\/\\\\/g; s/"/\\"/g')

	APPEND_NETWORK_CFG "$NET_PROF_SSID" "$NET_PROF_PASS" "$NET_PROF_SSID_WPA" "$((9 - ${NET_PROF_PR:-5}))"
done
