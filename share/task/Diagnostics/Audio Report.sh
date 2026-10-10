#!/bin/sh
# HELP: Audio Report - Checks sound cards, mixer levels, PipeWire and the selected output, then saves a report to SD1
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "audio_report" "Audio Report"

DIAG_SECTION "muOS audio configuration"
DIAG_CONFIG "$MUOS_CONF_DEVICE/audio"
DIAG_KV "Saved volume" "$(GET_SAVED_AUDIO_VOLUME 2>/dev/null)"
DIAG_KV "Wait for audio setting" "$(GET_VAR "config" "settings/advanced/audio_ready" 2>/dev/null)"

DIAG_SECTION "Sound cards"
DIAG_FILE /proc/asound/cards
if ! grep -q '^ *[0-9]' /proc/asound/cards 2>/dev/null; then
	DIAG_FINDING "KERNEL" "The kernel has no sound cards. The audio codec driver did not load."
fi
DIAG_CMD "Playback devices" aplay -l
for STATUS in /proc/asound/card*/pcm*p/sub0/status; do
	[ -r "$STATUS" ] || continue
	DIAG_OUT "-- $STATUS"
	DIAG_READ "$STATUS" | DIAG_APPEND
	DIAG_READ "${STATUS%status}hw_params" | DIAG_APPEND
done

DIAG_SECTION "Mixer controls"
for CARD in /proc/asound/card[0-9]*; do
	[ -d "$CARD" ] || continue
	NUMBER=${CARD##*card}
	DIAG_CMD "Card $NUMBER controls" amixer -c "$NUMBER" contents
	MUTED=$(amixer -c "$NUMBER" scontents 2>/dev/null | awk '/^Simple mixer control/ { name = $0 } /Playback.*\[off\]/ { print name }' | sort -u)
	[ -n "$MUTED" ] && DIAG_FINDING "MIXER" "Card $NUMBER has muted playback controls: $(printf '%s' "$MUTED" | sed "s/Simple mixer control //" | tr '\n' ' ')"
	ZERO=$(amixer -c "$NUMBER" scontents 2>/dev/null | awk '/^Simple mixer control/ { name = $0 } /Playback.*\[0%\]/ { print name }' | sort -u)
	[ -n "$ZERO" ] && DIAG_FINDING "MIXER" "Card $NUMBER has playback controls at 0%: $(printf '%s' "$ZERO" | sed "s/Simple mixer control //" | tr '\n' ' ')"
done

DIAG_SECTION "PipeWire"
for DAEMON in pipewire wireplumber pipewire-pulse; do
	if DIAG_RUNNING "$DAEMON"; then
		DIAG_KV "$DAEMON" "running ($(pidof "$DAEMON"))"
	else
		DIAG_KV "$DAEMON" "not running"
	fi
done
DIAG_RUNNING pipewire || DIAG_FINDING "PIPEWIRE" "PipeWire is not running, so nothing can play sound."
DIAG_RUNNING wireplumber || DIAG_FINDING "PIPEWIRE" "WirePlumber is not running, so outputs are not managed or restored."

if command -v wpctl >/dev/null 2>&1 && DIAG_RUNNING pipewire; then
	DIAG_CMD "wpctl status" wpctl status
	VOLUME=$(timeout 5 wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
	DIAG_KV "Default sink volume" "${VOLUME:-unknown}"
	DIAG_KV "Current sink" "$(CURRENT_SINK_NAME 2>/dev/null)"
	case "$VOLUME" in
		"") DIAG_FINDING "PIPEWIRE" "There is no default audio output in PipeWire." ;;
		*MUTED*) DIAG_FINDING "PIPEWIRE" "The default audio output is muted." ;;
		"Volume: 0.00"*) DIAG_FINDING "PIPEWIRE" "The default audio output volume is 0." ;;
	esac
	DIAG_CMD "Default sink details" wpctl inspect @DEFAULT_AUDIO_SINK@
fi

DIAG_SECTION "Headphones and outputs"
for JACK in /sys/class/switch/*/state /sys/devices/virtual/switch/*/state; do
	[ -r "$JACK" ] && DIAG_KV "$(basename "$(dirname "$JACK")")" "$(DIAG_READ "$JACK")"
done
amixer -c 0 controls 2>/dev/null | grep -i "jack" | while IFS= read -r CONTROL; do
	NAME=$(printf '%s' "$CONTROL" | sed -n "s/.*name='\([^']*\)'.*/\1/p")
	[ -n "$NAME" ] && DIAG_KV "$NAME" "$(amixer -c 0 cget name="$NAME" 2>/dev/null | sed -n 's/.*: values=//p')"
done
DIAG_KV "Built-in output" "$(DIAG_READ "$MUOS_RUN_DIR/audio_builtin")"
DIAG_FILE "$MUOS_RUN_DIR/audio_sinks"

DIAG_SECTION "Kernel messages"
DIAG_DMESG "snd|audio|codec|asoc|i2s|tas5|amp|speaker|headphone|jack" 80

DIAG_FINISH "Audio report saved"
exit 0
