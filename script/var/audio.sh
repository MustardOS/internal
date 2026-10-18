#!/bin/sh

[ -n "${MUOS_AUDIO_LOADED-}" ] && return 0
MUOS_AUDIO_LOADED=1
[ -n "${MUOS_CONFIG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/config.sh"
[ -n "${MUOS_LOG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/log.sh"

MIXER_INIT=
MIXER_CONTROL=
MIXER_DVOL=

ENSURE_AUDIO_OUTPUT() {
	AUDIO_CARD="${1:-0}"
	AUDIO_PATH=$(GET_VAR "device" "audio/path")

	if [ -n "$AUDIO_PATH" ]; then
		amixer -q -c "$AUDIO_CARD" sset "Playback Path" "$AUDIO_PATH" 2>/dev/null
		amixer -q -c "$AUDIO_CARD" sset "Resume Path" ON 2>/dev/null
		amixer -q -c "$AUDIO_CARD" sset Speaker on 2>/dev/null
	fi

	case "$(GET_VAR "device" "board/name")" in
		rg*) ;;
		*) return 0 ;;
	esac

	for AUDIO_SWITCH in LINEOUT SPK; do
		AUDIO_STATE=$(amixer -c "$AUDIO_CARD" sget "$AUDIO_SWITCH" 2>/dev/null) || continue
		[ -n "$AUDIO_STATE" ] || continue

		case "$AUDIO_STATE" in
			*"[off]"*)
				LOG_WARN "$0" 0 "PIPEWIRE" "$(printf "Audio output '%s' was off, switching it back on" "$AUDIO_SWITCH")"
				amixer -q -c "$AUDIO_CARD" sset "$AUDIO_SWITCH" on 2>/dev/null
				;;
		esac
	done
}

RESET_MIXER() {
	if [ -z "$MIXER_INIT" ]; then
		MIXER_INIT=1
		MIXER_CONTROL=$(GET_VAR "device" "audio/control")
		MIXER_MAX=$(GET_VAR "device" "audio/max")
		[ -n "$MIXER_MAX" ] || MIXER_MAX=100

		case "$(GET_VAR "device" "board/name")" in
			rg-vita*) MIXER_DVOL=skip ;;
			mgx* | tui*) MIXER_DVOL=0 ;;
			*) MIXER_DVOL=$MIXER_MAX ;;
		esac
	fi

	[ -n "$MIXER_CONTROL" ] || return 1
	[ "$MIXER_DVOL" = "skip" ] && return 0

	amixer -c 0 sset "$MIXER_CONTROL" "${MIXER_DVOL}%" unmute >/dev/null 2>&1
	amixer set "Master" unmute >/dev/null 2>&1

	return 0
}

GET_SAVED_AUDIO_VOLUME() {
	SAVED_VOL=$(GET_VAR "config" "settings/general/volume")
	MIN_VOL=$(GET_VAR "device" "audio/min")
	MAX_VOL=$(GET_VAR "device" "audio/max")

	[ -n "$MIN_VOL" ] || MIN_VOL=0
	[ -n "$MAX_VOL" ] || MAX_VOL=100
	[ -n "$SAVED_VOL" ] || SAVED_VOL=$MIN_VOL

	[ "$SAVED_VOL" -lt "$MIN_VOL" ] && SAVED_VOL=$MIN_VOL
	[ "$SAVED_VOL" -gt "$MAX_VOL" ] && SAVED_VOL=$MAX_VOL

	printf "%s\n" "$SAVED_VOL"
}

SET_SAVED_AUDIO_VOLUME() {
	VALUE=$1

	MIN_VOL=$(GET_VAR "device" "audio/min")
	MAX_VOL=$(GET_VAR "device" "audio/max")

	[ -n "$MIN_VOL" ] || MIN_VOL=0
	[ -n "$MAX_VOL" ] || MAX_VOL=100
	[ -n "$VALUE" ] || VALUE=$MIN_VOL

	[ "$VALUE" -lt "$MIN_VOL" ] && VALUE=$MIN_VOL
	[ "$VALUE" -gt "$MAX_VOL" ] && VALUE=$MAX_VOL

	SET_VAR "config" "settings/general/volume" "$VALUE"

	return 0
}

AUDIO_VOLUME_DIR="/opt/muos/share/volume"
AUDIO_BUILTIN_FILE="$MUOS_RUN_DIR/audio_builtin"
HEADPHONE_FLAG="$MUOS_RUN_DIR/headphones"

AUDIO_SINK_SLOT() {
	[ -e "$1" ] && return 1
	/opt/muos/bin/fnv1a "$1"
}

OUTPUT_VOLUME_NAME() {
	OUT_NAME=$1

	if [ -e "$HEADPHONE_FLAG" ] && [ -r "$AUDIO_BUILTIN_FILE" ]; then
		BUILTIN_NAME=
		read -r BUILTIN_NAME <"$AUDIO_BUILTIN_FILE"
		[ -n "$OUT_NAME" ] && [ "$OUT_NAME" = "$BUILTIN_NAME" ] && OUT_NAME="$OUT_NAME (Headphones)"
	fi

	printf "%s\n" "$OUT_NAME"
}

STOP_STRAY_GPTOKEYB() {
	for GPTK_NAME in gptokeyb gptokeyb2; do
		pgrep "^$GPTK_NAME\$" >/dev/null 2>&1 || continue

		pkill "^$GPTK_NAME\$" 2>/dev/null
		sleep 0.2
		pgrep "^$GPTK_NAME\$" >/dev/null 2>&1 && pkill -9 "^$GPTK_NAME\$" 2>/dev/null

		LOG_WARN "$0" 0 "INPUT" "$(printf "Stopped %s left running by the last content" "$GPTK_NAME")"
	done
}

CURRENT_SINK_NAME() {
	IDX=$(GET_VAR "config" "settings/general/audiosink")
	[ -n "$IDX" ] || return 1

	sed -n "$((IDX + 1))p" "$MUOS_RUN_DIR/audio_sinks" 2>/dev/null
}

SAVE_SINK_VOLUME() {
	NAME=$(OUTPUT_VOLUME_NAME "$(CURRENT_SINK_NAME)")
	[ -n "$NAME" ] || return 1

	SLOT=$(AUDIO_SINK_SLOT "$NAME")
	[ -n "$SLOT" ] || return 1

	mkdir -p "$AUDIO_VOLUME_DIR"
	GET_SAVED_AUDIO_VOLUME >"$AUDIO_VOLUME_DIR/$SLOT"

	LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "Saved volume for '%s'" "$NAME")"
}

LOAD_SINK_VOLUME() {
	NAME=$1
	[ -n "$NAME" ] || NAME=$(CURRENT_SINK_NAME)
	NAME=$(OUTPUT_VOLUME_NAME "$NAME")
	[ -n "$NAME" ] || return 1

	SLOT=$(AUDIO_SINK_SLOT "$NAME")
	[ -f "$AUDIO_VOLUME_DIR/$SLOT" ] || return 1

	LEVEL=$(cat "$AUDIO_VOLUME_DIR/$SLOT" 2>/dev/null)
	[ -n "$LEVEL" ] || return 1

	SET_SAVED_AUDIO_VOLUME "$LEVEL"

	LOG_INFO "$0" 0 "AUDIOSINK" "$(printf "Restored volume for '%s'" "$NAME")"
}

RESTORE_AUDIO_VOLUME() {
	RESET_MIXER
	SAVED_VOL=$(GET_SAVED_AUDIO_VOLUME)

	for _ in 1 2 3 4 5 6 7 8 9 10; do
		wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && break
		sleep 0.5
	done

	wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
	MUOS_VOLUME_RESTORE=1 /opt/muos/script/device/audio.sh "$SAVED_VOL"
}

VOLUME_RAMP() {
	DIR="${1:-}"
	TARGET="${2:-}"
	STEP="${3:-5}"
	DELAY="${4:-0.01}"

	POWER_POP=$(GET_VAR "config" "settings/advanced/power_pop")
	[ -n "$POWER_POP" ] || POWER_POP=0

	[ "$POWER_POP" -eq 1 ] && return 0

	case "$DIR" in
		up | down) ;;
		*)
			printf "Usage: VOLUME_RAMP up|down [target%%] [step] [delay]\n" >&2
			return 1
			;;
	esac

	for _ in 1 2 3 4 5 6 7 8 9 10; do
		wpctl inspect @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1 && break
		sleep 0.5
	done

	CUR_PCT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/Volume:/{printf "%.0f", $2 * 100; exit}')
	[ -n "$CUR_PCT" ] || CUR_PCT=0

	case "$DIR" in
		up)
			[ -z "$TARGET" ] && TARGET=$(GET_SAVED_AUDIO_VOLUME)
			[ "$CUR_PCT" -gt "$TARGET" ] && CUR_PCT="$TARGET"

			while [ "$CUR_PCT" -lt "$TARGET" ]; do
				CUR_PCT=$((CUR_PCT + STEP))
				[ "$CUR_PCT" -gt "$TARGET" ] && CUR_PCT="$TARGET"

				wpctl set-volume @DEFAULT_AUDIO_SINK@ "${CUR_PCT}%" >/dev/null 2>&1
				sleep "$DELAY"
			done
			;;
		down)
			[ -n "$TARGET" ] || TARGET=0

			while [ "$CUR_PCT" -gt "$TARGET" ]; do
				CUR_PCT=$((CUR_PCT - STEP))
				[ "$CUR_PCT" -lt "$TARGET" ] && CUR_PCT="$TARGET"

				wpctl set-volume @DEFAULT_AUDIO_SINK@ "${CUR_PCT}%" >/dev/null 2>&1
				sleep "$DELAY"
			done

			[ "$TARGET" -eq 0 ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 >/dev/null 2>&1
			;;
	esac

	return 0
}
