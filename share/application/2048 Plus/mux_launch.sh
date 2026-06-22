#!/bin/sh
# HELP: 2048 Plus
# ICON: logo_2048
# GRID: 2048 Plus

. /opt/muos/script/var/func.sh

# Check for SETUP_APP (Jacaranda or newer)
if command -v SETUP_APP >/dev/null 2>&1; then
    # --- Jacaranda Logic ---
    SETUP_STAGE_OVERLAY
    APP_BIN="bin/love"
    SETUP_APP "love" ""

    if [ -d "$MUOS_SHARE_DIR/application/2048 Plus" ]; then
        APP_DIR="$MUOS_SHARE_DIR/application/2048 Plus"
    else
        APP_DIR="$MUOS_STORE_DIR/application/2048 Plus"
    fi
    cd "$APP_DIR/.game" || exit

    export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
    export XDG_DATA_HOME="$APP_DIR/.game/static"
    export HOME="$APP_DIR/.game/static"
    export LD_LIBRARY_PATH="$APP_DIR/.game/bin/libs.aarch64:$LD_LIBRARY_PATH"

    if pgrep -f "playbgm.sh" >/dev/null; then
        killall -q "playbgm.sh" "mpg123"
    fi

    GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2.armhf"
    SCREEN_WIDTH="$(GET_VAR device mux/width)"
    SCREEN_HEIGHT="$(GET_VAR device mux/height)"
    SCREEN_RESOLUTION="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

    # Workaround for RK3576 devices (Vita Pro etc.)
    if grep -q "rk3576" /proc/device-tree/compatible 2>/dev/null; then
        for _ml in /usr/lib/libmali.so /usr/lib/aarch64-linux-gnu/libmali.so; do
            [ -e "$_ml" ] && export SDL_VIDEO_EGL_DRIVER="$_ml" && break
        done
        export SDL_OPENGL_ES_DRIVER=1
    fi

    command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE on
    SET_VAR "system" "foreground_process" "love"
    $GPTOKEYB "love" &
    ./bin/love . "${SCREEN_RESOLUTION}" > "$APP_DIR/.game/2048 Plus.log" 2>&1
    kill -9 "$(pidof gptokeyb2.armhf)" 2>/dev/null || true
    command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE off

else
    # --- Legacy Logic (Loose Goose / Older) ---

    SCREEN_WIDTH=$(GET_VAR device mux/width)
    SCREEN_HEIGHT=$(GET_VAR device mux/height)
    SCREEN_RESOLUTION="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

    if pgrep -f "playbgm.sh" >/dev/null; then
        killall -q "playbgm.sh" "mpg123"
    fi

    echo app >/tmp/act_go

    if [ -d "$MUOS_SHARE_DIR/application/2048 Plus" ]; then
        APP_DIR="$MUOS_SHARE_DIR/application/2048 Plus"
    else
        APP_DIR="$MUOS_STORE_DIR/application/2048 Plus"
    fi
    LOVEDIR="$APP_DIR/.game"
    GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2.armhf"
    STATICDIR="$LOVEDIR/static/"
    BINDIR="$LOVEDIR/bin"

    SETUP_SDL_ENVIRONMENT
    export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"
    export XDG_DATA_HOME="$STATICDIR"
    export HOME="$STATICDIR"
    export LD_LIBRARY_PATH="$BINDIR/libs.aarch64:$LD_LIBRARY_PATH"

    # Mirror glyphs (Legacy requirement)
    PRIMARY_APP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application"
    APP_DIR="$(dirname "$LOVEDIR")"
    SRC_GLYPH_DIR="$APP_DIR/glyph"
    DEST_APP_DIR="$PRIMARY_APP_DIR/2048 Plus"
    DEST_GLYPH_DIR="$DEST_APP_DIR/glyph"

    case "$APP_DIR/" in
    "$PRIMARY_APP_DIR"/*) : ;;
    *)
        if [ -d "$SRC_GLYPH_DIR" ]; then
            mkdir -p "$DEST_GLYPH_DIR" 2>/dev/null || true
            cp -rf "$SRC_GLYPH_DIR"/. "$DEST_GLYPH_DIR"/ 2>/dev/null || true
        fi
        ;;
    esac

    cd "$LOVEDIR" || exit
    SET_VAR "system" "foreground_process" "love"

    # Workaround for RK3576 devices (Vita Pro etc.)
    if grep -q "rk3576" /proc/device-tree/compatible 2>/dev/null; then
        for _ml in /usr/lib/libmali.so /usr/lib/aarch64-linux-gnu/libmali.so; do
            [ -e "$_ml" ] && export SDL_VIDEO_EGL_DRIVER="$_ml" && break
        done
        export SDL_OPENGL_ES_DRIVER=1
    fi

    command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE on
    $GPTOKEYB "love" &
    ./bin/love . "${SCREEN_RESOLUTION}" > "$LOVEDIR/2048 Plus.log" 2>&1
    kill -9 "$(pidof gptokeyb2.armhf)" 2>/dev/null || true
    command -v CAFFEINE >/dev/null 2>&1 && CAFFEINE off
fi
