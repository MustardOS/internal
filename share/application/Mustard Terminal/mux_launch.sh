#!/bin/sh
# HELP: A virtual terminal for direct shell access, be careful out there!
# ICON: terminal
# GRID: Terminal

. /opt/muos/script/var/func.sh

APP_BIN="muterm"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

cd "$HOME" || exit

MUTERM_CON="muterm.conf"
MUTERM_LOC="/root/.config/muterm/$MUTERM_CON"
MUTERM_DEF="$DEVICE_CONTROL_DIR/$MUTERM_CON"

if [ ! -e "$MUTERM_LOC" ]; then
	mkdir -p "$(dirname "$MUTERM_LOC")"
	if [ -e "$MUTERM_DEF" ]; then
		cp -f "$MUTERM_DEF" "$MUTERM_LOC"
	fi
fi

/opt/muos/bin/muterm
