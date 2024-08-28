#!/bin/sh

USAGE() {
	printf 'Usage: %s {init|save}\n' "$0" >&2
	exit 1
}

[ "$#" -eq 1 ] || USAGE

case "$1" in
	init | save) ;;
	*) USAGE ;;
esac

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/init/system.sh

ACTION="$1"

CONFIG_CLEARED=0
CONFIG_FILE="$GLOBAL_CONFIG"

BOOT_VARS="factory_reset device_setup clock_setup firmware_done"
CLOCK_VARS="notation pool"
NETWORK_VARS="enabled type ssid address gateway subnet dns"
SETTINGS_GENERAL_VARS="hidden bgm sound startup power low_battery colour brightness hdmi shutdown language"
SETTINGS_ADVANCED_VARS="swap thermal font verbose volume brightness offset lock led random_theme retrowait android state"
VISUAL_VARS="battery network bluetooth clock boxart name dash thetitleformat counterfolder counterfile"
WEB_VARS="shell browser terminal syncthing resilio ntp"
STORAGE_VARS="bios config catalogue content music save screenshot theme"

for INIT in boot clock network settings/general settings/advanced visual web storage; do
	case "$INIT" in
		boot) VARS="$BOOT_VARS" ;;
		clock) VARS="$CLOCK_VARS" ;;
		network) VARS="$NETWORK_VARS" ;;
		settings/general) VARS="$SETTINGS_GENERAL_VARS" ;;
		settings/advanced) VARS="$SETTINGS_ADVANCED_VARS" ;;
		visual) VARS="$VISUAL_VARS" ;;
		web) VARS="$WEB_VARS" ;;
		storage) VARS="$STORAGE_VARS" ;;
		*)
			printf "'%s' is unknown to %s\n" "$INIT" "$(basename "$0" .sh)"
			continue
			;;
	esac

	case "$ACTION" in
		init)
			BASE_DIR="/run/muos/$(basename "$0" .sh)/$INIT"
			mkdir -p "$BASE_DIR"
			for VAR in $VARS; do
				VAR_VALUE=$(PARSE_INI "$CONFIG_FILE" "$(echo "$INIT" | sed 's/\//./g')" "$VAR")
				SET_VAR "$(basename "$0" .sh)" "$INIT/$VAR" "$VAR_VALUE"
			done
			chmod -R 755 "$BASE_DIR"
			;;
		save)
			if [ $CONFIG_CLEARED -eq 0 ]; then
				: >"$CONFIG_FILE"
				CONFIG_CLEARED=1
			fi
			KEY_VALUES=""
			for VAR in $VARS; do
				VALUE=$(GET_VAR "$(basename "$0" .sh)/$INIT" "$VAR")
				KEY_VALUES=$(printf "%s\n%s" "$KEY_VALUES" "$VAR = $VALUE")
			done
			printf "[%s]%s\n\n" "$(echo "$INIT" | sed 's/\//./g')" "$KEY_VALUES" >>"$CONFIG_FILE"
			;;
	esac
done
