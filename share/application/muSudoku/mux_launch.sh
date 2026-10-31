#!/bin/sh
# HELP: muSudoku
# ICON: musudoku
# GRID: muSudoku

# muOS (MustardOS) application launcher for muSudoku.
# Structure follows the muOS application runner conventions.

. /opt/muos/script/var/func.sh

APP_NAME="muSudoku"

# Find the installed app folder. The script's own folder is the most
# reliable; the muOS paths are fallbacks.
APP_DIRECTORY="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
for CANDIDATE in \
    "$APP_DIRECTORY" \
    "/run/muos/storage/application/$APP_NAME" \
    "$MUOS_SHARE_DIR/application/$APP_NAME" \
    "$MUOS_STORE_DIR/application/$APP_NAME"; do
    if [ -n "$CANDIDATE" ] && [ -f "$CANDIDATE/.game/main.lua" ]; then
        APP_DIRECTORY="$CANDIDATE"
        break
    fi
done

GAME_DIRECTORY="$APP_DIRECTORY/.game"
SAVE_DIRECTORY="$GAME_DIRECTORY/save"
PACKS_DIRECTORY="$APP_DIRECTORY/packs"   # puzzle packs: MUOS/application/muSudoku/packs
BIN_DIRECTORY="$GAME_DIRECTORY/bin"
LOVE_BINARY="$BIN_DIRECTORY/love"
LOG_FILE="$GAME_DIRECTORY/musudoku.log"

SCREEN_WIDTH="$(GET_VAR device mux/width)"
SCREEN_HEIGHT="$(GET_VAR device mux/height)"
SCREEN_RESOLUTION="${SCREEN_WIDTH:-720}x${SCREEN_HEIGHT:-480}"
CAFFEINE="$(command -v CAFFEINE 2>/dev/null || true)"

SET_LOVE_ENVIRONMENT() {
    mkdir -p "$SAVE_DIRECTORY" "$PACKS_DIRECTORY"
    export MUSUDOKU_PACKS="$PACKS_DIRECTORY"
    # Saves go to .game/save/love/musudoku inside the app folder.
    export XDG_DATA_HOME="$SAVE_DIRECTORY"
    export HOME="$SAVE_DIRECTORY"
    export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
    export LD_LIBRARY_PATH="/usr/lib:/usr/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$BIN_DIRECTORY/libs.aarch64"
    chmod +x "$LOVE_BINARY" 2>/dev/null || true
}

SET_MALI_EGL_DRIVER() {
    if [ ! -e /dev/mali0 ] && [ ! -e /dev/mali ]; then
        return 0
    fi
    for MALI_LIBRARY in /usr/lib/libmali.so /usr/lib/aarch64-linux-gnu/libmali.so; do
        if [ -e "$MALI_LIBRARY" ]; then
            export SDL_VIDEO_EGL_DRIVER="$MALI_LIBRARY"
            export SDL_OPENGL_ES_DRIVER=1
            return 0
        fi
    done
}

START_LOVE() {
    [ -n "$CAFFEINE" ] && "$CAFFEINE" on
    SET_VAR "system" "foreground_process" "love"
    "$LOVE_BINARY" . "$SCREEN_RESOLUTION" > "$LOG_FILE" 2>&1
    [ -n "$CAFFEINE" ] && "$CAFFEINE" off
}

if command -v SETUP_APP >/dev/null 2>&1; then
    # Current muOS: SETUP_APP handles the CPU governor and SDL environment
    SETUP_STAGE_OVERLAY
    SETUP_APP "love" ""
    cd "$GAME_DIRECTORY" || exit 1
    SET_LOVE_ENVIRONMENT
    START_LOVE
else
    # Older muOS releases
    killall -q "playbgm.sh" "mpg123" 2>/dev/null || true
    echo app >/tmp/act_go
    SETUP_SDL_ENVIRONMENT
    cd "$GAME_DIRECTORY" || exit 1
    SET_LOVE_ENVIRONMENT
    SET_MALI_EGL_DRIVER
    START_LOVE
fi
