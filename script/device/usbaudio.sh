#!/bin/sh

. /opt/muos/script/var/func.sh

export XDG_RUNTIME_DIR=/run

LOCK="$MUOS_RUN_DIR/usbaudio.pid"

if [ -r "$LOCK" ]; then
	OLD_PID=$(cat "$LOCK" 2>/dev/null)
	if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
		LOG_INFO "$0" 0 "USBAUDIO" "$(printf "Already running as %s" "$OLD_PID")"
		exit 0
	fi
fi

printf "%s" "$$" >"$LOCK"

SINK_SCRIPT="/opt/muos/script/mux/audio_sink.sh"
AUDIO_SINKS="$MUOS_RUN_DIR/audio_sinks"

USB_AUDIO_PRESENT() {
	# The ALSA card list names the USB Audio driver for most devices
	grep -qi "usb" /proc/asound/cards 2>/dev/null && return 0

	# Some report nothing useful there, so fall back to the USB audio interface class
	for CLASS in /sys/bus/usb/devices/*/bInterfaceClass; do
		[ -r "$CLASS" ] || continue
		[ "$(cat "$CLASS" 2>/dev/null)" = "01" ] && return 0
	done

	return 1
}

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

LAST=""
SWITCHED=0

while true; do
	if [ "$(GET_VAR "config" "boot/device_mode")" = "1" ]; then
		sleep 2
		continue
	fi

	if USB_AUDIO_PRESENT; then
		NOW=1
	else
		NOW=0
	fi

	if [ "$NOW" != "$LAST" ]; then
		if [ "$NOW" = "1" ]; then
			# PipeWire needs a moment to register the card...
			IDX=""
			TRIES=0

			while [ "$TRIES" -lt 8 ]; do
				"$SINK_SCRIPT" list >/dev/null 2>&1

				IDX=$(USB_SINK_INDEX)
				[ -n "$IDX" ] && break

				TRIES=$((TRIES + 1))
				sleep 0.25
			done

			if [ -n "$IDX" ]; then
				"$SINK_SCRIPT" set "$IDX" >/dev/null 2>&1

				sleep 0.2
				SET_VAR "config" "settings/general/audiosink" "$IDX"

				SWITCHED=1
				LOG_SUCCESS "$0" 0 "USBAUDIO" "$(printf "Switched to USB audio sink %s" "$IDX")"
			else
				LOG_WARN "$0" 0 "USBAUDIO" "USB audio card present but no matching sink"
			fi
		elif [ "$SWITCHED" = "1" ]; then
			"$SINK_SCRIPT" set-builtin >/dev/null 2>&1
			"$SINK_SCRIPT" list >/dev/null 2>&1

			SWITCHED=0
			LOG_SUCCESS "$0" 0 "USBAUDIO" "USB audio removed, back to built-in"
		fi

		LAST="$NOW"
	fi

	sleep 0.3
done
