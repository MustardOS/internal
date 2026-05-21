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

	# Fucking HDMI Audio Output...
	pw-dump 2>/dev/null | jq -r '
		.[] |
		select(.type == "PipeWire:Interface:Node") |
		select(.info.props["media.class"] == "Audio/Sink") |
		(.info.props["node.description"] // .info.props["node.name"] // "Unknown") as $desc |
		(
			(.info.props["node.name"] // "") +
			(.info.props["api.alsa.path"] // "") +
			(.info.props["api.alsa.card.name"] // "")
			| ascii_downcase | contains("hdmi")
		) as $is_hdmi |
		(if $is_hdmi then "HDMI Audio" else $desc end) as $label |
		[(.id | tostring), $label] |
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
}

DO_SET_BT() {
	MAC="$1"
	[ -z "$MAC" ] && {
		LOG_ERROR "$0" 0 "AUDIOSINK" "No MAC address provided for set-bt"
		exit 1
	}

	if ! PIPEWIRE_READY; then
		LOG_WARN "$0" 0 "AUDIOSINK" "PipeWire not available - cannot set BT sink"
		return 1
	fi

	MAC_UPPER=$(printf "%s" "$MAC" | tr '[:lower:]' '[:upper:]')

	ATTEMPTS=6
	NODE_ID=""
	while [ "$ATTEMPTS" -gt 0 ] && [ -z "$NODE_ID" ]; do
		NODE_ID=$(pw-dump 2>/dev/null | jq -r --arg mac "$MAC_UPPER" '
			.[] |
			select(.type == "PipeWire:Interface:Node") |
			select(.info.props["media.class"] == "Audio/Sink") |
			select((.info.props["api.bluez5.address"] // "" | ascii_upcase) == $mac) |
			.id | tostring
		' 2>/dev/null | head -1)
		[ -z "$NODE_ID" ] && sleep 1
		ATTEMPTS=$((ATTEMPTS - 1))
	done

	if [ -z "$NODE_ID" ]; then
		LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "No BT audio sink for '%s' - not an audio device or not ready" "$MAC")"
		return 0
	fi

	LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "Setting BT audio sink for '%s' (id=%s)" "$MAC" "$NODE_ID")"

	wpctl set-default "$NODE_ID" >/dev/null 2>&1

	LOG_SUCCESS "$0" 0 "AUDIOSINK" "$(printf "BT audio sink active for '%s' (id=%s)" "$MAC" "$NODE_ID")"
}

DO_SET_BUILTIN() {
	if ! PIPEWIRE_READY; then
		LOG_WARN "$0" 0 "AUDIOSINK" "PipeWire not available - cannot revert sink"
		return 1
	fi

	NODE_ID=$(pw-dump 2>/dev/null | jq -r '
		.[] |
		select(.type == "PipeWire:Interface:Node") |
		select(.info.props["media.class"] == "Audio/Sink") |
		select((.info.props["api.bluez5.address"] // "") == "") |
		.id | tostring
	' 2>/dev/null | head -1)

	if [ -z "$NODE_ID" ]; then
		LOG_WARN "$0" 0 "AUDIOSINK" "No built-in audio sink found"
		return 1
	fi

	LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "Reverting to built-in sink (id=%s)" "$NODE_ID")"

	wpctl set-default "$NODE_ID" >/dev/null 2>&1

	LOG_SUCCESS "$0" 0 "AUDIOSINK" "$(printf "Reverted to built-in sink (id=%s)" "$NODE_ID")"
}

case "${1:-}" in
	list) DO_LIST ;;
	set) DO_SET "$2" ;;
	set-bt) DO_SET_BT "$2" ;;
	set-builtin) DO_SET_BUILTIN ;;
	*)
		printf "Usage: %s {list|set <index>|set-bt <mac>|set-builtin}\n" "$0"
		exit 1
		;;
esac
