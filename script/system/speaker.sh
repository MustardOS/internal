#!/bin/sh

. /opt/muos/script/var/func.sh

PID_FILE=/tmp/muos/speaker.pid
RATE=${RATE:-8000}
CHANNELS=${CHANNELS:-1}
FMT=${FMT:-S16_LE}
NICE=${NICE:-19}
ALSA_DEV=${ALSA_DEV:-default}

USAGE() {
	echo "Usage: $0 {start|stop}"
	exit 2
}

RUNNING() {
	[ -s "$PID_FILE" ] && PID=$(cat "$PID_FILE" 2>/dev/null) && kill -0 "$PID" 2>/dev/null
}

SPAWN_PW_PLAY() {
	(exec nice -n "$NICE" pw-play --rate "$RATE" --channels "$CHANNELS" --format "$FMT" /dev/zero) &
	echo $!
}

SPAWN_APLAY() {
	(exec nice -n "$NICE" aplay -q -D "$ALSA_DEV" -f "$FMT" -c "$CHANNELS" \
		-r "$RATE" --buffer-time=1000000 --period-time=250000 /dev/zero) &
	echo $!
}

SPAWN_MPV() {
	MPV_FMT=$(printf "%s" "$FMT" | tr '[:upper:]' '[:lower:]' | tr -d '_')
	(exec nice -n "$NICE" mpv --no-video --really-quiet \
		--demuxer=rawaudio --audio-format="$MPV_FMT" \
		--audio-channels="$CHANNELS" --audio-samplerate="$RATE" \
		--loop-file=inf /dev/zero) &
	echo $!
}

TRY_BACKEND() {
	PID=$($1)
	[ -z "$PID" ] && return 1

	echo "$PID" >"$PID_FILE"
	TBOX sleep 0.5

	kill -0 "$PID" 2>/dev/null || {
		rm -f "$PID_FILE"
		return 1
	}

	return 0
}

START() {
	RUNNING && exit 0

	command -v pw-play >/dev/null 2>&1 && TRY_BACKEND SPAWN_PW_PLAY && exit 0
	command -v aplay >/dev/null 2>&1 && TRY_BACKEND SPAWN_APLAY && exit 0
	command -v mpv >/dev/null 2>&1 && TRY_BACKEND SPAWN_MPV && exit 0

	exit 1
}

STOP() {
	if RUNNING; then
		PID=$(cat "$PID_FILE" 2>/dev/null)
		kill "$PID" 2>/dev/null

		/opt/muos/bin/toybox 0.5

		kill -9 "$PID" 2>/dev/null
		rm -f "$PID_FILE"
	fi
}

case "$1" in
	start) START ;;
	stop) STOP ;;
	*) USAGE ;;
esac
