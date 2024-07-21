#!/bin/sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mp3play"
fi

if pgrep -f "muplay" >/dev/null; then
	killall -q "muplay"
	rm "$SND_PIPE"
fi

echo app >/tmp/act_go

. /opt/muos/script/var/func.sh

AUDIO_SRC="/tmp/mux_audio_src"

GMU_DIR="$DC_STO_ROM_MOUNT/MUOS/application/.gmu"
GPTOKEYB="$DC_STO_ROM_MOUNT/MUOS/emulator/gptokeyb/gptokeyb2.armhf"

cd "$GMU_DIR" || exit

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib32/gamecontrollerdb.txt"
export LD_LIBRARY_PATH=/usr/lib32

echo "gmu" >/tmp/fg_proc

echo "Switching to ALSA-only configuration..."
pkill -9 golden.sh pw-play
cp /etc/asound.conf /etc/asound.conf.bak
cp /etc/asound.conf.alsa /etc/asound.conf
echo "alsa" >"$AUDIO_SRC"
amixer -c 0 sset "digital volume" 50%

$GPTOKEYB "./gmu" -c "$GMU_DIR/gmu.gptk" &
HOME="$GMU_DIR" SDL_ASSERT=always_ignore $SDL_GAMECONTROLLERCONFIG ./gmu -d "$GMU_DIR" -c "$GMU_DIR/gmu.conf"

kill -9 "$(pidof gptokeyb2.armhf)"
unset SDL_GAMECONTROLLERCONFIG_FILE
unset LD_LIBRARY_PATH

if [ -f /etc/asound.conf.bak ]; then
	mv /etc/asound.conf.bak /etc/asound.conf
fi

echo "pipewire" >"$AUDIO_SRC"
amixer -c 0 sset "digital volume" 100%
/opt/muos/golden.sh &
