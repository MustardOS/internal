#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "AUDIOSINK" "Audio sink manager starting"

AUDIO_SINKS="$MUOS_RUN_DIR/audio_sinks"
AUDIO_SINKS_RAW="$MUOS_RUN_DIR/audio_sinks_raw"
PW_SOCKET="${PIPEWIRE_RUNTIME_DIR:-/run}/pipewire-0"

PIPEWIRE_READY() {
	[ -S "$PW_SOCKET" ] && pw-cli info 0 >/dev/null 2>&1
}

SAVE_ACTIVE_SINK() {
	NODE_ID="$1"
	DO_LIST
	SINK_IDX=$(awk -v id="$NODE_ID" 'BEGIN{FS="\t"} $1==id{print NR-1;exit}' "$AUDIO_SINKS_RAW")
	[ -n "$SINK_IDX" ] && SET_VAR "config" "settings/general/audiosink" "$SINK_IDX"
}

GET_DEFAULT_SINK_ID() {
	DEF_NAME=$(pw-dump 2>/dev/null | jq -r '
		.[] |
		select(.type == "PipeWire:Interface:Metadata") |
		.metadata[]? |
		select(.key == "default.audio.sink") |
		.value.name // empty
	' 2>/dev/null | head -1)

	[ -z "$DEF_NAME" ] && return 1

	pw-dump 2>/dev/null | jq -r --arg name "$DEF_NAME" '
		first(
			.[] |
			select(.type == "PipeWire:Interface:Node") |
			select(.info.props["node.name"] == $name) |
			.id | tostring
		) // empty
	' 2>/dev/null
}

# Resync the saved sink index to whatever sink is actually the live default
SYNC_ACTIVE_INDEX() {
	DEFAULT_ID=$(GET_DEFAULT_SINK_ID)
	[ -z "$DEFAULT_ID" ] && return 0

	ACTIVE_IDX=$(awk -v id="$DEFAULT_ID" 'BEGIN{FS="\t"} $1==id{print NR-1;exit}' "$AUDIO_SINKS_RAW")
	[ -n "$ACTIVE_IDX" ] && SET_VAR "config" "settings/general/audiosink" "$ACTIVE_IDX"
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
	CONSOLE_MODE=$(GET_VAR "config" "boot/device_mode")

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
		# HDMI audio is only valid in console (HDMI output) mode
		[ "${CONSOLE_MODE:-0}" -ne 1 ] && [ "$NAME" = "HDMI Audio" ] && continue
		printf "%s\n" "$NAME" >>"$TMP_SINKS"
		printf "%s\t%s\n" "$ID" "$NAME" >>"$TMP_SINKS_RAW"
	done

	mv -f "$TMP_SINKS" "$AUDIO_SINKS"
	mv -f "$TMP_SINKS_RAW" "$AUDIO_SINKS_RAW"

	SYNC_ACTIVE_INDEX

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

	# BT autoconnect can fire before PipeWire has finished initialising at
	# boot so wait briefly for it to become ready before routing
	PW_ATTEMPTS=30
	while [ "$PW_ATTEMPTS" -gt 0 ] && ! PIPEWIRE_READY; do
		sleep 1
		PW_ATTEMPTS=$((PW_ATTEMPTS - 1))
	done

	if ! PIPEWIRE_READY; then
		LOG_WARN "$0" 0 "AUDIOSINK" "PipeWire not available - cannot set BT sink"
		return 1
	fi

	MAC_UPPER=$(printf "%s" "$MAC" | tr '[:lower:]' '[:upper:]')

	ATTEMPTS=15
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
		DO_SET_BUILTIN
		return 0
	fi

	LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "Setting BT audio sink for '%s' (id=%s)" "$MAC" "$NODE_ID")"

	wpctl set-default "$NODE_ID" >/dev/null 2>&1
	SAVE_ACTIVE_SINK "$NODE_ID"

	# The PipeWire node appears before the BlueZ A2DP codec handshake
	# completes; switching too quickly causes silence ~10% of the time on
	# reboot. Sleep briefly then restore the saved volume — the BT sink
	# starts at its own default level, not the configured system volume.
	sleep 1
	RESTORE_AUDIO_VOLUME

	LOG_SUCCESS "$0" 0 "AUDIOSINK" "$(printf "BT audio sink active for '%s' (id=%s)" "$MAC" "$NODE_ID")"
}

DO_SET_BUILTIN() {
	if ! PIPEWIRE_READY; then
		LOG_WARN "$0" 0 "AUDIOSINK" "PipeWire not available - cannot revert sink"
		return 1
	fi

	BOOT_CONSOLE_MODE=$(GET_VAR "config" "boot/device_mode")

	if [ "${BOOT_CONSOLE_MODE:-0}" -eq 1 ]; then
		TARGET_NAME=$(GET_VAR "device" "audio/pf_external")
	else
		TARGET_NAME=$(GET_VAR "device" "audio/pf_internal")
	fi

	NODE_ID=$(pw-dump 2>/dev/null | jq -r --arg name "$TARGET_NAME" '
		first(
			.[] |
			select(.type == "PipeWire:Interface:Node") |
			select(.info.props["node.name"] == $name) |
			.id | tostring
		) // empty
	' 2>/dev/null)

	if [ -z "$NODE_ID" ]; then
		LOG_WARN "$0" 0 "AUDIOSINK" "Default audio node not found"
		return 1
	fi

	LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "Reverting to default sink (id=%s)" "$NODE_ID")"

	wpctl set-default "$NODE_ID" >/dev/null 2>&1
	SAVE_ACTIVE_SINK "$NODE_ID"

	LOG_SUCCESS "$0" 0 "AUDIOSINK" "$(printf "Reverted to default sink (id=%s)" "$NODE_ID")"
}

DO_SAVE_NODE() {
	NODE_ID="$1"
	[ -z "$NODE_ID" ] && return 1

	if ! PIPEWIRE_READY; then
		LOG_WARN "$0" 0 "AUDIOSINK" "PipeWire not available"
		return 1
	fi

	SAVE_ACTIVE_SINK "$NODE_ID"
}

case "${1:-}" in
	list) DO_LIST ;;
	set) DO_SET "$2" ;;
	set-bt) DO_SET_BT "$2" ;;
	set-builtin) DO_SET_BUILTIN ;;
	save-node) DO_SAVE_NODE "$2" ;;
	*)
		printf "Usage: %s {list|set <index>|set-bt <mac>|set-builtin|save-node <id>}\n" "$0"
		exit 1
		;;
esac
