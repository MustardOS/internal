#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "AUDIOSINK" "Audio sink manager starting"

AUDIO_SINKS="$MUOS_RUN_DIR/audio_sinks"
AUDIO_SINKS_RAW="$MUOS_RUN_DIR/audio_sinks_raw"
PW_SOCKET="${PIPEWIRE_RUNTIME_DIR:-/run}/pipewire-0"

PIPEWIRE_READY() {
	[ -S "$PW_SOCKET" ] && pw-cli info 0 >/dev/null 2>&1
}

DO_LIST() {
	LOG_INFO "$0" 0 "AUDIOSINK" "Enumerating PipeWire audio sinks"

	if ! PIPEWIRE_READY; then
		LOG_WARN "$0" 0 "AUDIOSINK" "PipeWire not available"
		: >"$AUDIO_SINKS"
		: >"$AUDIO_SINKS_RAW"
		return 1
	fi

	TMP_SINKS="$MUOS_RUN_DIR/audio_sinks.tmp.$$"
	TMP_SINKS_RAW="$MUOS_RUN_DIR/audio_sinks_raw.tmp.$$"
	: >"$TMP_SINKS"
	: >"$TMP_SINKS_RAW"

	TAB=$(printf '\t')

	# Will have to split the H700 audio streams since both speakers and HDMI have the same fucking name!

	pw-dump 2>/dev/null | jq -r '
		.[] |
		select(.type == "PipeWire:Interface:Node") |
		select(.info.props["media.class"] == "Audio/Sink") |
		[(.id | tostring), (.info.props["node.description"] // .info.props["node.name"] // "Unknown")] |
		join("\t")
	' 2>/dev/null | while IFS="$TAB" read -r ID NAME; do
		[ -z "$ID" ] && continue
		printf "%s\n" "$NAME" >>"$TMP_SINKS"
		printf "%s\t%s\n" "$ID" "$NAME" >>"$TMP_SINKS_RAW"
	done

	mv -f "$TMP_SINKS" "$AUDIO_SINKS"
	mv -f "$TMP_SINKS_RAW" "$AUDIO_SINKS_RAW"

	COUNT=$(wc -l <"$AUDIO_SINKS" 2>/dev/null)
	LOG_SUCCESS "$0" 0 "AUDIOSINK" "$(printf "Found %s audio sink(s)" "${COUNT:-0}")"
}

DO_SET() {
	INDEX="$1"
	[ -z "$INDEX" ] && {
		LOG_ERROR "$0" 0 "AUDIOSINK" "No index provided for set"
		exit 1
	}

	if ! PIPEWIRE_READY; then
		LOG_WARN "$0" 0 "AUDIOSINK" "PipeWire not available - cannot set sink"
		return 1
	fi

	[ -r "$AUDIO_SINKS_RAW" ] || {
		LOG_ERROR "$0" 0 "AUDIOSINK" "Sink list not found; run list first"
		exit 1
	}

	LINE_NUM=$((INDEX + 1))
	LINE=$(awk "NR==$LINE_NUM" "$AUDIO_SINKS_RAW")

	if [ -z "$LINE" ]; then
		LOG_ERROR "$0" 0 "AUDIOSINK" "$(printf "Sink index %s out of range" "$INDEX")"
		exit 1
	fi

	NODE_ID=$(printf "%s" "$LINE" | cut -f1)
	SINK_NAME=$(printf "%s" "$LINE" | cut -f2-)

	LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "Setting default sink to '%s' (id=%s)" "$SINK_NAME" "$NODE_ID")"

	if wpctl set-default "$NODE_ID" >/dev/null 2>&1; then
		LOG_SUCCESS "$0" 0 "AUDIOSINK" "$(printf "Default sink set to '%s'" "$SINK_NAME")"
	else
		LOG_ERROR "$0" 0 "AUDIOSINK" "$(printf "Failed to set default sink to '%s'" "$SINK_NAME")"
		exit 1
	fi

	if command -v pactl >/dev/null 2>&1; then
		TAB=$(printf '\t')
		pactl list short sink-inputs 2>/dev/null | while IFS="$TAB" read -r INPUT_ID REST; do
			[ -z "$INPUT_ID" ] && continue
			LOG_DEBUG "$0" 0 "AUDIOSINK" "$(printf "Moving sink-input %s to node %s" "$INPUT_ID" "$NODE_ID")"
			pactl move-sink-input "$INPUT_ID" "$NODE_ID" >/dev/null 2>&1
		done
	fi
}

case "${1:-}" in
	list) DO_LIST ;;
	set) DO_SET "$2" ;;
	*)
		printf "Usage: %s {list|set <index>}\n" "$0"
		exit 1
		;;
esac
