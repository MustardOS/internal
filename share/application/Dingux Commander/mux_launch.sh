#!/bin/sh
# HELP: Dingux Commander
# ICON: dingux
# GRID: Dingux

. /opt/muos/script/var/func.sh

APP_BIN="dingux"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

DINGUX_DIR="$1"
cd "$DINGUX_DIR" || exit

if [ "$(GET_VAR "device" "mux/width")" -gt 1000 ]; then
	./$APP_BIN --config "$DINGUX_DIR/dingux-hi-res.cfg" --res-dir "res-hi"
else
	./$APP_BIN --config "$DINGUX_DIR/dingux.cfg"
fi
