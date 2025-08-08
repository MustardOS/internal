#!/bin/sh

. /opt/muos/script/var/func.sh

UPDATE_BUTTON_VALUE() {
	BUTTON_NAME=$1
	EXPECTED_VALUE=$2

	RA_DEV_CONF="/opt/muos/device/control/retroarch.device.cfg"

	# Read and update current value if it doesn't match the expected value
	if ! grep -q "^$BUTTON_NAME = \"$EXPECTED_VALUE\"" "$RA_DEV_CONF"; then
		sed -i "s|^$BUTTON_NAME = \".*\"|$BUTTON_NAME = \"$EXPECTED_VALUE\"|" "$RA_DEV_CONF"
		printf "Updated %s to %s\n" "$BUTTON_NAME" "$EXPECTED_VALUE"
	fi
}

SWAP_CONTROL_SCHEME() {
	# Determine the selected control style based on swap setting [0=Retro, 1=Modern]
	if [ "$1" -eq 0 ]; then
		UPDATE_BUTTON_VALUE "menu_swap_ok_cancel_buttons" "false"
		echo "retro"
	else
		UPDATE_BUTTON_VALUE "menu_swap_ok_cancel_buttons" "true"
		echo "modern"
	fi
}

if [ -e "$CON_GO" ]; then
	case "$(cat "$CON_GO")" in
		modern) UPDATE_BUTTON_VALUE "menu_swap_ok_cancel_buttons" "true" ;;
		retro) UPDATE_BUTTON_VALUE "menu_swap_ok_cancel_buttons" "false" ;;
		*) SWAP_CONTROL_SCHEME "$(GET_VAR "config" "settings/advanced/swap")" ;;
	esac
else
	SELECTED_MAP=$(SWAP_CONTROL_SCHEME "$(GET_VAR "config" "settings/advanced/swap")")

	# Remove any existing SDL map symlink and create a new one based on selected style
	for LIB_D in lib lib32; do
		SDL_MAP_PATH="/usr/$LIB_D/gamecontrollerdb.txt"
		[ -f "$SDL_MAP_PATH" ] && rm -f "$SDL_MAP_PATH"
		ln -s "/opt/muos/device/control/gamecontrollerdb_${SELECTED_MAP}.txt" "$SDL_MAP_PATH"
	done
fi
