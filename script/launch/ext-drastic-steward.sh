#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

. /opt/muos/script/var/global/storage.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

killall -q "golden.sh" "pw-play"
echo "Switching to ALSA-only configuration..."
cp /etc/asound.conf /etc/asound.conf.bak
cp /etc/asound.conf.alsa /etc/asound.conf
echo "alsa" >"$AUDIO_SRC"
amixer -c 0 sset "digital volume" 75%

echo "drastic" >/tmp/fg_proc

EMUDIR="$DC_STO_ROM_MOUNT/MUOS/emulator/drastic-steward"

# Replace the save state location to where the user set it to!
SETTINGS_FILE="$EMUDIR/resources/settings.json"
sed -i "s|\(\"states\":\"\)[^\"]*|\1$GC_STO_SAVE/MUOS/save/drastic|g" "$SETTINGS_FILE"

chmod +x "$EMUDIR"/launch.sh
cd "$EMUDIR" || exit

HOME="$EMUDIR" SDL_ASSERT=always_ignore ./launch.sh "$ROM"

unset SDL_HQ_SCALER
unset SDL_ROTATION
unset SDL_BLITTER_DISABLED

if [ -f /etc/asound.conf.bak ]; then
	mv /etc/asound.conf.bak /etc/asound.conf
fi

echo "pipewire" >"$AUDIO_SRC"
amixer -c 0 sset "digital volume" 100%
/opt/muos/golden.sh &
