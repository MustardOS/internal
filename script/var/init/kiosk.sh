#!/bin/sh

USAGE() {
	printf 'Usage: %s {init}\n' "$0" >&2
	exit 1
}

[ "$#" -eq 1 ] || USAGE

case "$1" in
	init) ;;
	*) USAGE ;;
esac

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/init/system.sh

ACTION="$1"

CONFIG_FILE="$KIOSK_CONFIG"

APPLICATION_VARS="archive task"
CONFIG_VARS="custom language network storage webserv"
CONTENT_VARS="core governor option retroarch search"
CUSTOM_VARS="catalogue configuration theme"
DATETIME_VARS="clock timezone"
LAUNCH_VARS="application config explore collection history info"
SETTING_VARS="advanced general hdmi power visual"

for INIT in application config content custom datetime launch setting; do
	case "$INIT" in
		application) VARS="$APPLICATION_VARS" ;;
		config) VARS="$CONFIG_VARS" ;;
		content) VARS="$CONTENT_VARS" ;;
		custom) VARS="$CUSTOM_VARS" ;;
		datetime) VARS="$DATETIME_VARS" ;;
		launch) VARS="$LAUNCH_VARS" ;;
		setting) VARS="$SETTING_VARS" ;;
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
	esac
done
