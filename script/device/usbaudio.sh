#!/bin/sh

. /opt/muos/script/var/audio.sh

export XDG_RUNTIME_DIR=/run

SINK_SCRIPT="/opt/muos/script/mux/audio_sink.sh"
AUDIO_SINKS="$MUOS_RUN_DIR/audio_sinks"

# The card list names the device, and PipeWire labels its sink with that name plus a
# profile suffix, so the card name is what ties the two together
USB_CARD_NAME() {
	awk -F' - ' '/USB-Audio/ { sub(/[ \t]+$/, "", $2); print $2; exit }' /proc/asound/cards 2>/dev/null
}

USB_SINK_INDEX() {
	NAME=$(USB_CARD_NAME)

	if [ -n "$NAME" ]; then
		IDX=$(awk -v n="$NAME" 'index($0, n) > 0 { print NR - 1; exit }' "$AUDIO_SINKS" 2>/dev/null)
		[ -n "$IDX" ] && printf "%s" "$IDX" && return 0
	fi

	# Some devices label the sink rather than the card, so try the obvious words too
	awk 'tolower($0) ~ /usb|headset|earbud|earphone/ { print NR - 1; exit }' "$AUDIO_SINKS" 2>/dev/null
}

[ "$(GET_VAR "config" "boot/device_mode")" = "1" ] && exit 76

case "$1" in
	1)
		[ "$2" = "1" ] || SAVE_SINK_VOLUME

		IDX=""
		TRIES=0

		while [ "$TRIES" -lt 8 ]; do
			"$SINK_SCRIPT" list >/dev/null 2>&1

			IDX=$(USB_SINK_INDEX)
			[ -n "$IDX" ] && break

			TRIES=$((TRIES + 1))
			sleep 0.25
		done

		if [ -z "$IDX" ]; then
			LOG_WARN "$0" 0 "USBAUDIO" "USB audio present but no sink yet"
			exit 75
		fi

		"$SINK_SCRIPT" set "$IDX" >/dev/null 2>&1

		sleep 0.2
		SET_VAR "config" "settings/general/audiosink" "$IDX"

		LOG_SUCCESS "$0" 0 "USBAUDIO" "$(printf "Switched to USB audio sink %s" "$IDX")"
		;;
	0)
		SAVE_SINK_VOLUME

		"$SINK_SCRIPT" set-builtin >/dev/null 2>&1
		"$SINK_SCRIPT" list >/dev/null 2>&1

		LOG_SUCCESS "$0" 0 "USBAUDIO" "USB audio removed, back to built-in"
		;;
esac
