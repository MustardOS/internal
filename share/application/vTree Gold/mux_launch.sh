#!/bin/sh
# HELP: vTree Gold
# ICON: vtree
# GRID: vTree

. /opt/muos/script/var/func.sh

SETUP_STAGE_OVERLAY

APP_BIN="vtree"
SETUP_APP "$APP_BIN" ""

# -----------------------------------------------------------------------------

VTREE_DIR="$1"
cd "$VTREE_DIR" || exit

./"$APP_BIN" --logfile="${VTREE_DIR}/vtree.log"