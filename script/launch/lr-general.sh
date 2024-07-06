#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

. /opt/muos/script/var/global/setting_general.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

if echo "$CORE" | grep -q "flycast"; then
	export SDL_NO_SIGNAL_HANDLERS=1
fi

if echo "$CORE" | grep -q "morpheuscast"; then
	export SDL_NO_SIGNAL_HANDLERS=1
fi

if echo "$CORE" | grep -q "j2me"; then
	export SDL_NO_SIGNAL_HANDLERS=1
	export JAVA_HOME=/opt/java
	PATH=$PATH:$JAVA_HOME/bin
fi

echo "retroarch" >/tmp/fg_proc

retroarch -v -f -c "$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg" -L "$DC_STO_ROM_MOUNT/MUOS/core/$CORE" "$ROM" &
RA_PID=$!

# We have to pause just for a moment to let RetroArch finish loading...
sleep 5

if [ "$GC_GEN_STARTUP" = last ] || [ "$GC_GEN_STARTUP" = resume ]; then
	if [ ! -e "/tmp/manual_launch" ]; then
		retroarch --command LOAD_STATE
	fi
fi

wait $RA_PID
