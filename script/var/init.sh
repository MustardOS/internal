#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/init/system.sh

USAGE() {
	printf 'Usage: %s <init|save> <device|global|kiosk>\n' "$0" >&2
	exit 1
}

[ $# -ne 2 ] && USAGE

ACTION="$1"
SCOPE="$2"

case "$SCOPE" in
	device)
		CONFIG_PATH="/run/muos/device"
		CONFIG_FILE="$DEVICE_CONFIG"
		;;
	global)
		CONFIG_PATH="/run/muos/global"
		CONFIG_FILE="$GLOBAL_CONFIG"
		;;
	kiosk)
		CONFIG_PATH="/run/muos/kiosk"
		CONFIG_FILE="$KIOSK_CONFIG"
		;;
	*) USAGE ;;
esac

case "$ACTION" in
	init)
		[ ! -f "$CONFIG_FILE" ] && {
			printf "Error: Config file '%s' does not exist.\n" "$CONFIG_FILE" >&2
			exit 1
		}

		awk -v base="$CONFIG_PATH" '
			BEGIN { section = "" }

			$0 ~ /^\[[^]]+\]$/ {
				line = $0
				sub(/^[ \t]+/, "", line)
				sub(/[ \t]+$/, "", line)
				if (match(line, /^\[.*\]$/)) {
					section = substr(line, RSTART + 1, RLENGTH - 2)
					gsub(/\./, "/", section)
				}
				next
			}

			/=/ && $0 !~ /^#/ {
				pos = index($0, "=")
				if (pos > 1) {
					key = substr($0, 1, pos - 1)
					value = substr($0, pos + 1)

					sub(/[ \t]+$/, "", key)
					sub(/^[ \t]+/, "", value)

					dir = base "/" section
					file = dir "/" key

					printf("mkdir -p \"%s\"\n", dir)
					printf("printf %%s \"%s\" >\"%s\"\n", value, file)
				}
			}
		' "$CONFIG_FILE" | sh
		;;

	save)
		: >"$CONFIG_FILE"

		find "$CONFIG_PATH" -type f | while IFS= read -r FILEPATH; do
			REL_PATH=${FILEPATH#"$CONFIG_PATH"/}
			SECTION=$(printf "%s" "${REL_PATH%/*}" | tr '/' '.')

			if ! grep -q "^\[$SECTION\]$" "$CONFIG_FILE"; then
				printf "\n[%s]\n" "$SECTION" >>"$CONFIG_FILE"
			fi

			printf "%s = %s\n" "${REL_PATH##*/}" "$(cat "$FILEPATH")" >>"$CONFIG_FILE"
		done

		sed -i '1{/^$/d;}' "$CONFIG_FILE"
		;;

	*) USAGE ;;
esac
