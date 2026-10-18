#!/bin/sh

. /opt/muos/script/var/display.sh
. /opt/muos/script/var/launch.sh

# The fbdev blitter synchronises scanout to the panel.  Disabling it exposes
# uneven application submission cadence as visible repeats/flicker.
SETUP_SDL_ENVIRONMENT skip_blitter

SET_VAR "system" "foreground_process" "muxretro"

# FreeJ2ME starts its Java side with a bare "java", so the runtime has to be on the path
if echo "$CORE" | grep -q "j2me"; then
	export JAVA_HOME="$MUOS_SHARE_DIR/emulator/zulu"
	PATH=$JAVA_HOME/bin:$PATH
	export PATH

	# Pickles stops Java outright while paused, so FreeJ2ME must not pause the game itself on resume
	FREEJ2ME_NO_AUTOPAUSE=1
	export FREEJ2ME_NO_AUTOPAUSE

	# FreeJ2ME keeps a copy of its options per game and prefers it over the core options, so a
	# changed resolution would never apply. Game saves live in rms and are left alone.
	find "$MUOS_STORE_DIR/pickles/sram/freej2me/freej2me/config" -type f -name game.conf -exec rm -f {} + 2>/dev/null
fi

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/$CORE" "$FILE" $FRESH_ARG
