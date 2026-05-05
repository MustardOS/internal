#!/bin/bash
# HELP: A music player app focused on a clean and fast user experience.
# ICON: songo
# GRID: Songo#5

. /opt/muos/script/var/func.sh

APP_BIN="sbc_4_3_rcv12"
SETUP_APP "$APP_BIN" ""

# End of muOS header config

# Start of Songo#5 launch
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAMEDIR="$SCRIPT_DIR/songo5"

#runtime="sbc_4_3_rcv12"
pck_filename="Songo5.pck"
#gptk_filename="songo5.gptk"

# Logging
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Create directory for save files
CONFDIR="$GAMEDIR/conf/"
$ESUDO mkdir -p "${CONFDIR}"


# Setup volume indicator
USE_SONGO_VOL_TCP_SERVER="0"
SONGO_CFW_NAME="muOS"

if [[ "$SONGO_CFW_NAME" != "NONE" ]]; then
	USE_SONGO_VOL_TCP_SERVER="1"
	sh "${GAMEDIR}/runtime/volume-indicator/setup_vol_indicator" "${SONGO_CFW_NAME}"
fi

export SONGO_CFW_NAME
export CFW_NAME="muOS"
export USE_SONGO_VOL_TCP_SERVER
export SONGO_DIR_TIP="On muOS I suggest making a MUSIC folder in /mnt/mmc/"

# Set up brightness commands (Based on IncognitoMans approach)
export SYSFS_BL_BRIGHTNESS="$(find /sys/class/backlight/*/ -name brightness 2>/dev/null | head -n 1)"
export SYSFS_BL_COMMAND="$(find /sys/kernel/debug/dispdbg/ -name command 2>/dev/null | head -n 1)"

if [ -n "${SYSFS_BL_BRIGHTNESS}" ]; then
  echo "Backlight TYPE2 detected! setting path/type."
  export BL_TYPE="TYPE2"
  export SYSFS_BL_POWER="$(find /sys/class/backlight/*/ -name bl_power )"
  export SYSFS_BL_MAX="$(find /sys/class/backlight/*/ -name max_brightness 2>/dev/null | head -n 1)"
elif [ -n "${SYSFS_BL_COMMAND}" ]; then
  echo "Backlight TYPE1 detected! setting path/type."
  export BL_TYPE="TYPE1"
  export SYSFS_BL_NAME="$(find /sys/kernel/debug/dispdbg/ -name name 2>/dev/null | head -n 1)"
  export SYSFS_BL_PARAM="$(find /sys/kernel/debug/dispdbg/ -name param 2>/dev/null | head -n 1)"
  export SYSFS_BL_START="$(find /sys/kernel/debug/dispdbg/ -name start 2>/dev/null | head -n 1)"
  export BL_COMMAND="setbl"
  export BL_NAME="lcd0"
else
  echo "Backlight objects not found!"
  export BL_TYPE="UNKNOWN"
fi

DEFAULT_GET_BRIGHTNESS_PATH="${GAMEDIR}/runtime/brightness/default/get_brightness"
DEFAULT_SET_BRIGHTNESS_PATH="${GAMEDIR}/runtime/brightness/default/set_brightness"
SONGO_GET_BRIGHTNESS_PATH="$DEFAULT_GET_BRIGHTNESS_PATH"
SONGO_SET_BRIGHTNESS_PATH="$DEFAULT_SET_BRIGHTNESS_PATH"
NO_BRIGHT_FADE_AVAILABLE='0'

if [[ "$BL_TYPE" = "TYPE1" ]] && [[ -e "${GAMEDIR}/runtime/brightness/${SONGO_CFW_NAME}/get_brightness" ]]; then
	# Type 2 updates the stored get value when cfw adjusts brightness, so for type 1 we have to explicitly check if
	# brightness has been adjusted by the user
	SONGO_GET_BRIGHTNESS_PATH="${GAMEDIR}/runtime/brightness/${SONGO_CFW_NAME}/get_brightness"
fi

if [ "$BL_TYPE" = "UNKNOWN" ]; then
	NO_BRIGHT_FADE_AVAILABLE='1'
fi

INITIAL_BRIGHTNESS="$("$SONGO_GET_BRIGHTNESS_PATH")"
if [ -z "$INITIAL_BRIGHTNESS" ]; then
    echo "Failed to read initial brightness" >&2
    INITIAL_BRIGHTNESS=50  # fallback value if needed
fi

export SONGO_GET_BRIGHTNESS_PATH
export SONGO_SET_BRIGHTNESS_PATH
export NO_BRIGHT_FADE_AVAILABLE

export HIDE_MOUSE="true"

if [[ "$SONGO_CFW_NAME" = "muOS" ]]; then
	export USERS_ORIGINAL_IDLE_SLEEP="$(GET_VAR "config" "settings/power/idle_sleep")"
	export USERS_ORIGINAL_IDLE_DISPLAY="$(GET_VAR "config" "settings/power/idle_display")"
	echo "Users original idle sleep: ${USERS_ORIGINAL_IDLE_SLEEP}"
	echo "Users original idle display: ${USERS_ORIGINAL_IDLE_DISPLAY}"
fi

# This is used to suppress cfw behavior when it interferes with expected music player behavior. EG disabling inactivity sleep while music is playing.
# When the app pauses/stops music it re-enables the targeted cfw behavior for a native like experience. EG if paused your screen may dim as per cfw config
if [[ -e "${GAMEDIR}/runtime/playback_suppressions/${SONGO_CFW_NAME}/set" ]]; then
	echo "Found suppressions for ${SONGO_CFW_NAME}"
	export SET_PLAYBACK_SUPPRESSIONS_PATH="${GAMEDIR}/runtime/playback_suppressions/${SONGO_CFW_NAME}/set"
	export REMOVE_PLAYBACK_SUPPRESSIONS_PATH="${GAMEDIR}/runtime/playback_suppressions/${SONGO_CFW_NAME}/remove"
else
	echo "No suppressions found for ${SONGO_CFW_NAME}"
fi

cd $GAMEDIR


# Set the XDG environment variables for config & savefiles
export XDG_DATA_HOME="$CONFDIR"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

echo "XDG_DATA_HOME"
echo $XDG_DATA_HOME

export SONGO_BINARIES_DIR="$GAMEDIR/runtime"

# gptokeyb was only being used for quit shortcut
#$GPTOKEYB "$GAMEDIR/runtime/$runtime" -c "$GAMEDIR/$gptk_filename" &

# Might need to uncomment this tsp stuff
# sleep 0.6 # For TSP only, do not move/modify this line.
# pm_platform_helper "$GAMEDIR/runtime/$runtime"

LD_LIBRARY_PATH="$GAMEDIR/runtime/ffmpeg:$LD_LIBRARY_PATH" "$GAMEDIR/runtime/$APP_BIN" $GODOT_OPTS --main-pack "gamedata/$pck_filename"


# Clean up after app close
CAFFEINE off
SET_VAR "config" "settings/power/idle_sleep" "$USERS_ORIGINAL_IDLE_SLEEP"
SET_VAR "config" "settings/power/idle_display" "$USERS_ORIGINAL_IDLE_DISPLAY"
HOTKEY restart

# Revert brightness if app crashes or brighntess ends up as zero for any reason
CURRENT_BRIGHTNESS="$("$SONGO_GET_BRIGHTNESS_PATH")"
if [ "$CURRENT_BRIGHTNESS" = "0" ]; then
    echo "Brightness is 0, restoring to $INITIAL_BRIGHTNESS"
    "$SONGO_SET_BRIGHTNESS_PATH" "$INITIAL_BRIGHTNESS"
fi

# Tear down volume indicator
if [[ "$SONGO_CFW_NAME" != "NONE" ]]; then
	sh "${GAMEDIR}/runtime/volume-indicator/teardown_vol_indicator" "${SONGO_CFW_NAME}"
fi


#pm_finish
