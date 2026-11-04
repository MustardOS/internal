#!/bin/sh

[ -n "${MUOS_WPA_LOADED-}" ] && return 0
MUOS_WPA_LOADED=1

# Prints one wpa_supplicant network block. The SSID is written as hex so any name works, and a
# passphrase is turned into its PSK through stdin so it never appears in the process list.
WPA_NETWORK() {
	WPA_SSID=$(printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n')
	[ -n "$WPA_SSID" ] && [ "${#WPA_SSID}" -le 64 ] || return 1

	case "$2" in
		"") WPA_KEY="key_mgmt=NONE" ;;
		*"
"*) return 1 ;;
		*)
			case "$2" in
				*[!0-9A-Fa-f]*) WPA_PSK= ;;
				*) WPA_PSK=$2 ;;
			esac
			[ "${#WPA_PSK}" -eq 64 ] ||
				WPA_PSK=$(printf '%s\n' "$2" | wpa_passphrase "$1" | sed -n 's/^[[:space:]]*psk=\([0-9A-Fa-f]\{64\}\)$/\1/p')
			[ -n "$WPA_PSK" ] || return 1
			WPA_KEY="psk=$WPA_PSK"
			;;
	esac

	printf 'network={\n\tssid=%s\n\tscan_ssid=1\n\t%s\n\tpriority=%s\n}\n' "$WPA_SSID" "$WPA_KEY" "$3"
}
