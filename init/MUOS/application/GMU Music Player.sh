#!/bin/sh
# HELP: GMU Music Player
# ICON: music

. /opt/muos/script/var/func.sh

if pgrep -f "playbgm.sh" >/dev/null; then
	killall -q "playbgm.sh" "mpg123"
fi

echo app >/tmp/act_go

AUDIO_SRC="/tmp/mux_audio_src"

GMU_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.gmu"
GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2.armhf"

cd "$GMU_DIR" || exit

export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib32/gamecontrollerdb.txt"
export LD_LIBRARY_PATH=/usr/lib32

SET_VAR "system" "foreground_process" "gmu"

killall -q "golden.sh" "pw-play" "pipewire" "wireplumber"

echo "Switching to ALSA-only configuration..."
cp /etc/asound.conf /etc/asound.conf.bak
cp /etc/asound.conf.alsa /etc/asound.conf
echo "alsa" >"$AUDIO_SRC"
amixer -c 0 sset \""$(GET_VAR "device" "audio/control")"\" "$(printf '%.0f%%' "$(echo "$(GET_VAR "audio" "pw_vol") * 100" | bc)")"

$GPTOKEYB "./gmu" -c "$GMU_DIR/gmu.gptk" &
HOME="$GMU_DIR" SDL_ASSERT=always_ignore $SDL_GAMECONTROLLERCONFIG ./gmu -d "$GMU_DIR" -c "$GMU_DIR/gmu.conf"

kill -9 "$(pidof gptokeyb2.armhf)"
unset SDL_GAMECONTROLLERCONFIG_FILE
unset LD_LIBRARY_PATH

if [ -f /etc/asound.conf.bak ]; then
	mv /etc/asound.conf.bak /etc/asound.conf
fi

echo "pipewire" >"$AUDIO_SRC"
/opt/muos/script/system/pipewire.sh

amixer -c 0 sset \""$(GET_VAR "device" "audio/control")"\" "$(printf '%.0f%%' "$(echo "$(GET_VAR "audio" "pw_vol") * 100" | bc)")"
/opt/muos/script/mux/golden.sh &
