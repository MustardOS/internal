#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
	LOG_INFO "$0" 0 "Content Launch" "DETAIL"
	LOG_INFO "$0" 0 "NAME" "$NAME"
	LOG_INFO "$0" 0 "CORE" "$CORE"
	LOG_INFO "$0" 0 "FILE" "$FILE"
) &

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

AZAHAR_BIN="azahar"
SET_VAR "system" "foreground_process" "$AZAHAR_BIN"

EMUDIR="$MUOS_SHARE_DIR/emulator/azahar"

# Setup Save Directories
SAVEDIR="$MUOS_STORE_DIR/save/azahar"
mkdir -p "$SAVEDIR"
mkdir -p "$SAVEDIR/nand"
mkdir -p "$SAVEDIR/sdmc"

chmod +x "$EMUDIR"/$AZAHAR_BIN
cd "$EMUDIR" || exit

export HOME="$EMUDIR"
XDG_CONFIG_HOME="$HOME/.config"

# Source for the active controller mapping. muOS rewrites a:/b:/x:/y: in this entry per
# Retro/Modern/Custom profile, so re-reading it each launch tracks the active profile.
GAMECONTROLLERDB="${GAMECONTROLLERDB:-/usr/lib/gamecontrollerdb.txt}"
# gamecontrollerdb.txt is SHARED across devices, so match the RG-Vita-Pro joypad's UNIQUE GUID
# (NOT a generic 'muOS-Keys' entry — that belongs to other devices and would mis-bind here).
# muOS keeps the GUID stable and rewrites this entry's a:/b:/x:/y: per Retro/Modern/Custom.
CONTROLLER_MATCH="${CONTROLLER_MATCH:-19009b4d4b4800000111000000010000}"  # RG-Vita-Pro joypad GUID

# --- Locate the active controller line --------------------------------------
CTRL_LINE=""
[ -f "$GAMECONTROLLERDB" ] && CTRL_LINE=$(grep -m1 "$CONTROLLER_MATCH" "$GAMECONTROLLERDB" 2>/dev/null)
[ -z "$CTRL_LINE" ] && [ -n "$SDL_GAMECONTROLLERCONFIG" ] && CTRL_LINE="$SDL_GAMECONTROLLERCONFIG"
if [ -n "$CTRL_LINE" ]; then
    echo "mux_launch: matched '$(printf '%s' "$CTRL_LINE" | cut -d, -f2)' ($CONTROLLER_MATCH)" >&2
else
    echo "mux_launch: WARNING - no controller mapping ($CONTROLLER_MATCH) in $GAMECONTROLLERDB" >&2
fi

# --- Helpers ----------------------------------------------------------------
# Extract a gamecontrollerdb token value, e.g. tok a -> "b0", tok dpup -> "h0.1"
tok() { printf '%s\n' "$CTRL_LINE" | tr ',' '\n' | grep -m1 "^$1:" | cut -d: -f2; }

# Translate a raw token (bN | aN | hX.M) into an Azahar SDL button param fragment.
btn_frag() {
    case "$1" in
        b*) printf 'button:%s' "${1#b}" ;;
        a*) printf 'axis:%s,threshold:0.5,direction:+' "${1#a}" ;;
        h*) hat=${1#h}; idx=${hat%.*}; val=${hat#*.}
            case "$val" in 1) d=up;; 2) d=right;; 4) d=down;; 8) d=left;; *) d=up;; esac
            printf 'hat:%s,direction:%s' "$idx" "$d" ;;
        *)  return 1 ;;
    esac
}

GUID=$(printf '%s' "$CTRL_LINE" | cut -d, -f1)

# set_key <key> <value>  — update under [Controls], inserting if absent
set_key() {
    if grep -qE "^$1=" "$CONFIG"; then
        sed -i "s|^$1=.*|$1=$2|" "$CONFIG"
    else
        sed -i "/^\[Controls\]/a $1=$2" "$CONFIG"
    fi
}

# 3DS button <- gamecontrollerdb logical button (so muOS swap follows through)
map_button() {  # $1 = azahar key, $2 = gamecontrollerdb logical name
    raw=$(tok "$2"); [ -z "$raw" ] && return
    frag=$(btn_frag "$raw") || return
    set_key "$1" "engine:sdl,guid:$GUID,port:0,$frag"
}

# circle pad / c-stick from two axes
map_analog() {  # $1 = azahar key, $2 = x logical, $3 = y logical
    ax=$(tok "$2"); ay=$(tok "$3")
    [ -z "$ax" ] || [ -z "$ay" ] && return
    set_key "$1" "engine:sdl,guid:$GUID,port:0,axis_x:${ax#a},axis_y:${ay#a},deadzone:0.15"
}

# --- Ensure config exists with Vulkan selected ------------------------------
#if [ ! -f "$CONFIG" ]; then
#    mkdir -p "$(dirname "$CONFIG")"
    # Default to side-by-side (layout_option=3) for the 16:9 landscape display.
    # Only seeded for fresh installs, so a user's later layout choice persists.
#    printf '[Renderer]\ngraphics_api=2\n\n[Layout]\nlayout_option=3\n\n[Controls]\n' > "$CONFIG"
#fi
#grep -qE '^graphics_api=' "$CONFIG" \
#    && sed -i 's|^graphics_api=.*|graphics_api=2|' "$CONFIG" \
#    || sed -i '/^\[Renderer\]/a graphics_api=2' "$CONFIG"

# --- Generate controls from the active profile ------------------------------
if [ -n "$CTRL_LINE" ]; then
    map_button button_a a
    map_button button_b b
    map_button button_x x
    map_button button_y y
    map_button button_l leftshoulder
    map_button button_r rightshoulder
    map_button button_zl lefttrigger
    map_button button_zr righttrigger
    map_button button_select back
    map_button button_start start
    map_button button_home guide
    map_button button_up dpup
    map_button button_down dpdown
    map_button button_left dpleft
    map_button button_right dpright
    map_analog circle_pad leftx lefty
    map_analog c_stick rightx righty
fi

# --- Hotkeys ----------------------------------------------------------------
# Modifier (default Guide) held with an action button:
#   + rightshoulder -> cycle 3DS layout (Default / SingleScreen / LargeScreen / SideScreen / Hybrid)
#   + leftshoulder  -> toggle swap_screen (which 3DS screen is primary)
#   + start         -> request a clean exit
# Each is derived from the active controller profile so the same combos work on any muOS device.
# Only exported when the token is a raw button (bN); axis/hat fall back to compiled-in defaults.
if [ -n "$CTRL_LINE" ]; then
    _hk_mod=$(tok guide); _hk_lay=$(tok rightshoulder)
    _hk_swap=$(tok leftshoulder); _hk_exit=$(tok start)
    [ "${_hk_mod#b}"  != "$_hk_mod"  ] && export AZAHAR_HOTKEY_MOD="${_hk_mod#b}"
    [ "${_hk_lay#b}"  != "$_hk_lay"  ] && export AZAHAR_HOTKEY_LAYOUT="${_hk_lay#b}"
    [ "${_hk_swap#b}" != "$_hk_swap" ] && export AZAHAR_HOTKEY_SWAP="${_hk_swap#b}"
    [ "${_hk_exit#b}" != "$_hk_exit" ] && export AZAHAR_HOTKEY_EXIT="${_hk_exit#b}"
    echo "ext-azahar: hotkey mod=b${AZAHAR_HOTKEY_MOD:-?} layout=b${AZAHAR_HOTKEY_LAYOUT:-?} swap=b${AZAHAR_HOTKEY_SWAP:-?} exit=b${AZAHAR_HOTKEY_EXIT:-?}" >&2
fi

SDL_ASSERT=always_ignore ./$AZAHAR_BIN "$FILE"
