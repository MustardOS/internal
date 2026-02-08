#!/bin/bash
# HELP: RGB Controller
# ICON: rgbcontroller
# GRID: RGB

. /opt/muos/script/var/func.sh

APP_BIN="love"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

LOVEDIR="$1"
cd "$LOVEDIR" || exit

export LD_LIBRARY_PATH="$LOVEDIR/libs:$LD_LIBRARY_PATH"

PM_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"
"$PM_DIR"/gptokeyb2 "$APP_BIN" &

CONFDIR="$LOVEDIR/conf/"
export XDG_DATA_HOME="$CONFDIR"

./$APP_BIN rgbcontroller
kill -9 "$(pidof gptokeyb2)"
