#!/bin/sh
# HELP: 2048 Plus
# ICON: logo_2048
# GRID: 2048 Plus

. /opt/muos/script/var/func.sh

APP_NAME="2048 Plus"
APP_SUBPATH="application/$APP_NAME"
APP_DIRECTORY="$MUOS_SHARE_DIR/$APP_SUBPATH"
[ -d "$APP_DIRECTORY" ] || APP_DIRECTORY="$MUOS_STORE_DIR/$APP_SUBPATH"
APP_GAME_DIRECTORY="$APP_DIRECTORY/.game"
APP_STATIC_DIRECTORY="$APP_GAME_DIRECTORY/static"
APP_BINARY_DIRECTORY="$APP_GAME_DIRECTORY/bin"
LOVE_BINARY="$APP_BINARY_DIRECTORY/love"
LOG_FILE="$APP_GAME_DIRECTORY/$APP_NAME.log"
ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
GPTOKEYB="$ROM_MOUNT/MUOS/emulator/gptokeyb/gptokeyb2.armhf"
SCREEN_WIDTH="$(GET_VAR device mux/width)"
SCREEN_HEIGHT="$(GET_VAR device mux/height)"
SCREEN_RESOLUTION="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
CAFFEINE="$(command -v CAFFEINE 2>/dev/null || true)"

STOP_MUSIC() {
    killall -q "playbgm.sh" "mpg123" 2>/dev/null || true
}

SET_LOVE_ENVIRONMENT() {
    export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
    export XDG_DATA_HOME="$APP_STATIC_DIRECTORY"
    export HOME="$APP_STATIC_DIRECTORY"
    export LD_LIBRARY_PATH="$APP_BINARY_DIRECTORY/libs.aarch64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
}

SET_RK3576_WORKAROUND() {
    grep -q "rk3576" /proc/device-tree/compatible 2>/dev/null || return 0

    for MALI_LIBRARY in /usr/lib/libmali.so /usr/lib/aarch64-linux-gnu/libmali.so; do
        if [ -e "$MALI_LIBRARY" ]; then
            export SDL_VIDEO_EGL_DRIVER="$MALI_LIBRARY"
            break
        fi
    done

    export SDL_OPENGL_ES_DRIVER=1
}

START_LOVE() {
    [ -n "$CAFFEINE" ] && "$CAFFEINE" on
    SET_VAR "system" "foreground_process" "love"
    "$GPTOKEYB" "love" &
    GPTOKEYB_PROCESS="$!"
    "$LOVE_BINARY" . "$SCREEN_RESOLUTION" > "$LOG_FILE" 2>&1
    kill "$GPTOKEYB_PROCESS" 2>/dev/null || kill -9 "$(pidof gptokeyb2.armhf)" 2>/dev/null || true
    wait "$GPTOKEYB_PROCESS" 2>/dev/null || true
    [ -n "$CAFFEINE" ] && "$CAFFEINE" off
}

# Check for SETUP_APP (Jacaranda or newer)
if command -v SETUP_APP >/dev/null 2>&1; then
    # --- Jacaranda Logic ---
    SETUP_STAGE_OVERLAY
    APP_BIN="bin/love"
    SETUP_APP "love" ""

    cd "$APP_GAME_DIRECTORY" || exit

    SET_LOVE_ENVIRONMENT

    # Workaround for RK3576 devices (Vita Pro etc.)
    SET_RK3576_WORKAROUND

    START_LOVE

else
    # --- Legacy Logic (Loose Goose / Older) ---

    STOP_MUSIC

    echo app >/tmp/act_go

    SETUP_SDL_ENVIRONMENT
    SET_LOVE_ENVIRONMENT

    # Mirror glyphs (Legacy requirement)
    PRIMARY_APP_DIRECTORY="$ROM_MOUNT/MUOS/application"
    CURRENT_APP_DIRECTORY="$APP_DIRECTORY"
    SOURCE_GLYPH_DIRECTORY="$CURRENT_APP_DIRECTORY/glyph"
    DESTINATION_APP_DIRECTORY="$PRIMARY_APP_DIRECTORY/$APP_NAME"
    DESTINATION_GLYPH_DIRECTORY="$DESTINATION_APP_DIRECTORY/glyph"

    case "$CURRENT_APP_DIRECTORY/" in
    "$PRIMARY_APP_DIRECTORY"/*) : ;;
    *)
        if [ -d "$SOURCE_GLYPH_DIRECTORY" ]; then
            mkdir -p "$DESTINATION_GLYPH_DIRECTORY" 2>/dev/null || true
            cp -rf "$SOURCE_GLYPH_DIRECTORY"/. "$DESTINATION_GLYPH_DIRECTORY"/ 2>/dev/null || true
        fi
        ;;
    esac

    cd "$APP_GAME_DIRECTORY" || exit

    # Workaround for RK3576 devices (Vita Pro etc.)
    SET_RK3576_WORKAROUND

    START_LOVE
fi
