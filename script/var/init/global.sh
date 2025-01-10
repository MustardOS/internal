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

CONFIG_FILE="$GLOBAL_CONFIG"

BOOT_VARS="factory_reset device_setup clock_setup firmware_done"
CLOCK_VARS="notation pool"
NETWORK_VARS="enabled type ssid pass address gateway subnet dns"
SETTINGS_ADVANCED_VARS="accelerate swap thermal font verbose rumble volume brightness offset lock led random_theme retrowait usb_function state user_init dpad_swap overdrive swapfile cardmode"
SETTINGS_GENERAL_VARS="hidden bgm sound startup colour brightness language"
SETTINGS_HDMI_VARS="enabled resolution theme_resolution space depth range scan audio"
SETTINGS_POWER_VARS="low_battery shutdown idle_display idle_sleep"
VISUAL_VARS="battery network bluetooth clock boxart boxartalign name dash friendlyfolder thetitleformat titleincluderootdrive counterfolder counterfile folderitemcount folderempty backgroundanimation launchsplash blackfade"
WEB_VARS="sshd sftpgo ttyd syncthing rslsync ntp tailscaled"

for INIT in boot clock network settings/advanced settings/general settings/hdmi settings/power visual web; do
	case "$INIT" in
		boot) VARS="$BOOT_VARS" ;;
		clock) VARS="$CLOCK_VARS" ;;
		network) VARS="$NETWORK_VARS" ;;
		settings/advanced) VARS="$SETTINGS_ADVANCED_VARS" ;;
		settings/general) VARS="$SETTINGS_GENERAL_VARS" ;;
		settings/hdmi) VARS="$SETTINGS_HDMI_VARS" ;;
		settings/power) VARS="$SETTINGS_POWER_VARS" ;;
		visual) VARS="$VISUAL_VARS" ;;
		web) VARS="$WEB_VARS" ;;
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
			KEY_VALUES=""
			for VAR in $VARS; do
				if [ -f "/run/muos/$(basename "$0" .sh)/$INIT/$VAR" ]; then
					VALUE=$(GET_VAR "$(basename "$0" .sh)/$INIT" "$VAR")
				else
					# Use default value for newly added var.
					# (Happens when installing a patch).
					VALUE=$(PARSE_INI "$CONFIG_FILE" "$(echo "$INIT" | sed 's/\//./g')" "$VAR")
				fi
				KEY_VALUES=$(printf "%s\n%s" "$KEY_VALUES" "$VAR = $VALUE")
			done
			printf "[%s]%s\n\n" "$(echo "$INIT" | sed 's/\//./g')" "$KEY_VALUES" >>"$CONFIG_FILE.sav"
			;;
	esac
done

if [ "$ACTION" = save ]; then
	mv -f "$CONFIG_FILE.sav" "$CONFIG_FILE"
fi
