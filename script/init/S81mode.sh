#!/bin/sh

[ -n "$MUOS_FUNC_LOADED" ] || . /opt/muos/script/var/func.sh

HDMI_PATH=$(GET_VAR "device" "screen/hdmi")
BOARD_HDMI=$(GET_VAR "device" "board/hdmi")

INTERNAL_WIDTH=$(GET_VAR "device" "screen/internal/width")
INTERNAL_HEIGHT=$(GET_VAR "device" "screen/internal/height")

BRIGHT_ADV=$(GET_VAR "config" "settings/advanced/brightness")
BRIGHT_DEF=$(GET_VAR "config" "settings/general/brightness")
BRIGHT_MAX=$(GET_VAR "device" "screen/bright")

HANDHELD_START() {
	SET_VAR "config" "boot/device_mode" "0"

	for SCREEN_MODE in screen mux; do
		SET_VAR "device" "$SCREEN_MODE/width" "$INTERNAL_WIDTH"
		SET_VAR "device" "$SCREEN_MODE/height" "$INTERNAL_HEIGHT"
	done

	/opt/muos/script/device/bright.sh R

	case "$BRIGHT_ADV" in
		3) /opt/muos/script/device/bright.sh "$BRIGHT_MAX" ;;
		2) /opt/muos/script/device/bright.sh 90 ;;
		1) /opt/muos/script/device/bright.sh 35 ;;
		*) /opt/muos/script/device/bright.sh "$BRIGHT_DEF" ;;
	esac
}

# This is the only place the display mode is decided, async init runs alongside it and must leave it alone
DO_START() {
	HDMI_VALUE=0

	if [ "${BOARD_HDMI:-0}" -eq 1 ] && [ -n "$HDMI_PATH" ] && [ -f "$HDMI_PATH" ]; then
		IFS= read -r HDMI_VALUE <"$HDMI_PATH"
	fi

	if [ "$HDMI_VALUE" = "1" ]; then
		SET_VAR "config" "boot/device_mode" "1"

		if ! /opt/muos/script/device/hdmi.sh; then
			LOG_WARN "$0" 0 "BOOTING" "HDMI switch failed, staying on the internal display"
			HANDHELD_START
		fi
	else
		HANDHELD_START
	fi

	/opt/muos/script/mux/audio_sink.sh list >/dev/null 2>&1 || :
}

case "$1" in
	start)
		DO_START
		;;
	stop)
		# Display mode and brightness state is managed at runtime by muOS
		;;
	restart)
		DO_START
		;;
	*)
		printf "Usage: %s {start|stop|restart}\n" "$0" >&2
		exit 1
		;;
esac
