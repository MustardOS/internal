#!/bin/sh
# HELP: RetroArch
# ICON: retroarch
# GRID: RetroArch

. /opt/muos/script/var/func.sh

APP_BIN="retroarch"
SETUP_APP "$APP_BIN" ""

SETUP_STAGE_OVERLAY

# -----------------------------------------------------------------------------

RA_CONF="$MUOS_SHARE_DIR/info/config/$APP_BIN.cfg"
RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

$APP_BIN -v -f $RA_ARGS

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP

CHEEVOS_USER=$(sed -n 's/^[[:space:]]*cheevos_username[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$RA_CONF" | head -n 1)
CHEEVOS_PASS=$(sed -n 's/^[[:space:]]*cheevos_password[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$RA_CONF" | head -n 1)

if [ -n "$CHEEVOS_USER" ] && [ -n "$CHEEVOS_PASS" ]; then
	CHEEVOS_CONF="$(dirname "$RA_CONF")/$APP_BIN.cheevos.cfg"
	TMP_CONF="/tmp/ra-cheevos.tmp"

	sed -n '/^[[:space:]]*cheevos_/p' "$RA_CONF" >"$TMP_CONF" && mv "$TMP_CONF" "$CHEEVOS_CONF"

	# The menu sublabels need to be shown for some weird RetroArch quirk
	# that has to do with the message pop ups or something like that...
	if ! grep -Eq '^[[:space:]]*menu_show_sublabels[[:space:]]*=' "$CHEEVOS_CONF"; then
		printf '%s\n' 'menu_show_sublabels = "true"' >>"$CHEEVOS_CONF"
	fi
fi
