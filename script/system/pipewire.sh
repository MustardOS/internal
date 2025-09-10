#!/bin/sh

. /opt/muos/script/var/func.sh

ACTION=$1
CARD="${CARD:-0}"

GET_NODE_ID() {
	PAT="$1"
	pw-dump |
		jq -r --arg pat "$PAT" '
		.[]
		| select(.type == "PipeWire:Interface:Node")
		| select((.info.props["media.class"] // "") | startswith("Audio/Sink"))
		| select((.info.props["node.name"] // "" | ascii_downcase)
		         | contains($pat | ascii_downcase))
		| .id
	' | head -n1
}

AMIX_TRY() {
	CTL=$1
	shift

	amixer -c "$CARD" sget "$CTL" >/dev/null 2>&1 || return 1
	amixer -c "$CARD" -q sset "$CTL" "$@" >/dev/null 2>&1
}

WAIT_GONE() {
	NAME=$1

	I=0
	while pgrep -x "$NAME" >/dev/null 2>&1; do
		TBOX sleep 0.1
		I=$((I + 1))
		[ "$I" -ge 30 ] && break
	done

	pgrep -x "$NAME" >/dev/null 2>&1 && return 1
	return 0
}

FADE_DOWN() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Fading sink volume down..."
	for _ in $(seq 1 8); do
		wpctl set-volume @DEFAULT_AUDIO_SINK@ 16%- || break
		TBOX sleep 0.1
	done

	wpctl set-volume @DEFAULT_AUDIO_SINK@ 0% 2>/dev/null
	wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
}

MUTE_CODEC_PATH() {
	for CTL in \
		"Master" "PCM" "DAC" "Speaker" "Speaker Playback Volume" "SPK" "Line Out" \
		"LOUT" "Playback" "Playback Volume" "DAC Playback Volume" "Digital"; do
		AMIX_TRY "$CTL" 0%
		AMIX_TRY "$CTL" mute
		AMIX_TRY "$CTL" off
	done
}

DISABLE_AMP() {
	# These are all of the controls I could see and some extras from examples
	# of amplifier names found on the information superhighway...
	for CTL in \
		"PA Enable" "Power Amplifier" "External Speaker" \
		"ClassD" "Speaker Amp" "SPK Amp" "AMP Enable"; do
		if AMIX_TRY "$CTL" off || AMIX_TRY "$CTL" 0; then
			return 0
		fi
	done

	return 1
}

STOP_AUDIO_STACK() {
	for PROC in muspeaker pipewire wireplumber; do
		LOG_INFO "$0" 0 "PIPEWIRE" "Stopping: %s (if running)" "$PROC"

		if killall -q -15 "$PROC" 2>/dev/null; then
			if ! WAIT_GONE "$PROC"; then
				killall -q -15 "$PROC" 2>/dev/null
			fi
		fi
	done
}

REQUIRE_DBUS() {
	for TIMEOUT in $(seq 1 30); do
		if [ -e "/run/dbus/system_bus_socket" ]; then
			LOG_SUCCESS "$0" 0 "PIPEWIRE" "D-Bus socket is available"
			return 0
		fi

		printf "(%d of 30) Waiting for D-Bus...\n" "$TIMEOUT"
		TBOX sleep 1
	done

	LOG_ERROR "$0" 0 "PIPEWIRE" "Timeout expired waiting for D-Bus"
	return 1
}

START_PIPEWIRE() {
	if ! pgrep -x "pipewire" >/dev/null; then
		LOG_INFO "$0" 0 "PIPEWIRE" "Starting PipeWire..."
		chrt -f 88 pipewire -c "$MUOS_SHARE_DIR/conf/pipewire.conf" &
	else
		LOG_WARN "$0" 0 "PIPEWIRE" "PipeWire is already running!"
		return 1
	fi

	LOG_INFO "$0" 0 "PIPEWIRE" "Waiting for PipeWire init..."

	for TIMEOUT in $(seq 1 30); do
		if pw-cli info >/dev/null 2>&1; then
			LOG_SUCCESS "$0" 0 "PIPEWIRE" "PipeWire is now active!"
			return 0
		fi
		printf "(%d of 30) PipeWire not responsive yet...\n" "$TIMEOUT"

		pgrep -l pipewire
		TBOX sleep 1
	done

	LOG_ERROR "$0" 0 "PIPEWIRE" "Timeout expired waiting for PipeWire...\nPipeWire:\n\t%s\nWirePlumber:\n\t%s\nPipeWire Socket:\n\t%s\n" \
		"$(pgrep -l pipewire)" \
		"$(pgrep -l wireplumber)" \
		"$(ls -l /run/pipewire-0 2>/dev/null)"
	return 1
}

SELECT_DEFAULT_NODE_AND_VOLUME() {
	for TIMEOUT in $(seq 1 30); do
		if pw-cli ls Node 2>/dev/null | grep -q "Audio/Sink"; then
			INTERNAL_NODE_ID=$(GET_NODE_ID "$(GET_VAR "device" "audio/pf_internal")")
			EXTERNAL_NODE_ID=$(GET_NODE_ID "$(GET_VAR "device" "audio/pf_external")")

			CONSOLE_MODE="$(GET_VAR "config" "boot/device_mode")"
			if [ "$CONSOLE_MODE" -eq 1 ]; then
				DEFAULT_NODE_ID=$EXTERNAL_NODE_ID
				if [ "$(GET_VAR "config" "settings/hdmi/audio")" -eq 1 ]; then
					DEFAULT_NODE_ID=$INTERNAL_NODE_ID
				fi
			else
				DEFAULT_NODE_ID=$INTERNAL_NODE_ID
			fi

			if [ -n "$DEFAULT_NODE_ID" ]; then
				LOG_INFO "$0" 0 "PIPEWIRE" "Setting default note to ID: %s" "$DEFAULT_NODE_ID"
				wpctl set-default "$DEFAULT_NODE_ID"

				case "$(GET_VAR "config" "settings/advanced/volume")" in
					"loud") VOLUME="$(GET_VAR "device" "audio/max")" ;;
					"soft") VOLUME="35" ;;
					"silent") VOLUME="0" ;;
					*) VOLUME="$(GET_VAR "config" "settings/general/volume")" ;;
				esac

				if [ "$CONSOLE_MODE" -eq 1 ]; then
					if [ "$(GET_VAR "config" "settings/advanced/overdrive")" -eq 1 ]; then
						wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%
					else
						wpctl set-volume @DEFAULT_AUDIO_SINK@ 100%
					fi
				else
					/opt/muos/script/device/audio.sh "$VOLUME"
				fi

				AUDIO_CONTROL="$(GET_VAR "device" "audio/control")"
				AUDIO_VOL_PCT="$(GET_VAR "device" "audio/volume")"
				amixer -c 0 sset "$AUDIO_CONTROL" "${AUDIO_VOL_PCT}%" unmute
				wpctl set-mute @DEFAULT_AUDIO_SINK@ 0

				/opt/muos/frontend/muspeaker &
				SET_VAR "device" "audio/ready" "1"

				return 0
			else
				LOG_WARN "$0" 0 "PIPEWIRE" "Node with ID '%s' not found" "$DEFAULT_NODE_ID"
				return 1
			fi
		fi

		printf "(%d of 30) PipeWire sink not found yet\n" "$TIMEOUT"
		TBOX sleep 1
	done

	LOG_ERROR "$0" 0 "PIPEWIRE" "Timeout expired waiting for PipeWire sink...\n%s\n\nCheck audio configuration" "$(pw-cli ls Node)"
	return 1
}

DO_START() {
	LOG_INFO "$0" 0 "PIPEWIRE" "D-Bus requirement checking"
	REQUIRE_DBUS || exit 1

	LOG_INFO "$0" 0 "PIPEWIRE" "Starting PipeWire itself"
	START_PIPEWIRE || exit 1

	LOG_INFO "$0" 0 "PIPEWIRE" "Choosing device specific node and setting volume"
	SELECT_DEFAULT_NODE_AND_VOLUME || exit 1
}

DO_STOP() {
	LOG_INFO "$0" 0 "PIPEWIRE" "Starting PipeWire audio shutdown sequence..."

	FADE_DOWN
	MUTE_CODEC_PATH
	TBOX sleep 0.25

	DISABLE_AMP
	TBOX sleep 0.25

	STOP_AUDIO_STACK
	SET_VAR "device" "audio/ready" "0"

	LOG_SUCCESS "$0" 0 "PIPEWIRE" "PipeWire audio shutdown complete!"
}

case "$ACTION" in
	start) DO_START ;;
	stop) DO_STOP ;;
	*)
		printf "Usage: %s {start|stop}\n" "$0"
		exit 1
		;;
esac
