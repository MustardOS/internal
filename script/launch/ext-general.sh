#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

if grep -q 'PORT_32BIT="Y"' "$ROM"; then
	killall -q "golden.sh" "pw-play"
	echo "Switching to ALSA-only configuration..."
	cp /etc/asound.conf /etc/asound.conf.bak
	cp /etc/asound.conf.alsa /etc/asound.conf
	echo "alsa" >"$AUDIO_SRC"
	amixer -c 0 sset "digital volume" 75%
fi

"$ROM"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED

if [ -f /etc/asound.conf.bak ]; then
	mv /etc/asound.conf.bak /etc/asound.conf
fi

echo "pipewire" >"$AUDIO_SRC"
amixer -c 0 sset "digital volume" 100%
/opt/muos/golden.sh &
