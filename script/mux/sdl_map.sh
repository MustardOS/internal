#!/bin/sh

. /opt/muos/script/var/func.sh

UPDATE_BUTTON_VALUE() {
	BUTTON_NAME=$1
	EXPECTED_VALUE=$2

	RA_DEV_CONF="/opt/muos/device/current/control/retroarch.device.cfg"

	# Read and update current value if it doesn't match the expected value
	if ! grep -q "^$BUTTON_NAME = \"$EXPECTED_VALUE\"" "$RA_DEV_CONF"; then
		sed -i "s|^$BUTTON_NAME = \".*\"|$BUTTON_NAME = \"$EXPECTED_VALUE\"|" "$RA_DEV_CONF"
		printf "Updated %s to %s\n" "$BUTTON_NAME" "$EXPECTED_VALUE"
	fi
}

# Determine the selected control style based on swap setting [0=Retro, 1=Modern]
if [ "$(GET_VAR "global" "settings/advanced/swap")" -eq 0 ]; then
	SELECTED_STYLE="Retro"
	SELECTED_MAP="gamecontrollerdb_retro.txt"
	UPDATE_BUTTON_VALUE "menu_swap_ok_cancel_buttons" "false"
else
	SELECTED_STYLE="Modern"
	SELECTED_MAP="gamecontrollerdb_modern.txt"
	UPDATE_BUTTON_VALUE "menu_swap_ok_cancel_buttons" "true"
fi

printf "%s Style Selected\n" "$SELECTED_STYLE"

# Remove any existing SDL map symlink and create a new one based on selected style
for LIB_D in lib lib32; do
	SDL_MAP_PATH="/usr/$LIB_D/gamecontrollerdb.txt"
	[ -f "$SDL_MAP_PATH" ] && rm -f "$SDL_MAP_PATH"
	ln -s "/opt/muos/device/current/control/$SELECTED_MAP" "$SDL_MAP_PATH"
done
