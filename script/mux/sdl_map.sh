#!/bin/sh

# Define default SDL button values
BTN_A_RETRO=$(cat "/run/muos/device/input/sdlmap/retro/a")
BTN_B_RETRO=$(cat "/run/muos/device/input/sdlmap/retro/b")
BTN_X_RETRO=$(cat "/run/muos/device/input/sdlmap/retro/x")
BTN_Y_RETRO=$(cat "/run/muos/device/input/sdlmap/retro/y")
BTN_A_MODERN=$(cat "/run/muos/device/input/sdlmap/modern/a")
BTN_B_MODERN=$(cat "/run/muos/device/input/sdlmap/modern/b")
BTN_X_MODERN=$(cat "/run/muos/device/input/sdlmap/modern/x")
BTN_Y_MODERN=$(cat "/run/muos/device/input/sdlmap/modern/y")

# Define device specific Retroarch controller map
RA_DEV_CONF="/opt/muos/device/current/control/retroarch.device.cfg"

# Determine current Retroarch controller values
BTN_A_CURR=$(grep 'input_player1_a_btn' "$RA_DEV_CONF" | cut -d '"' -f 2)
BTN_B_CURR=$(grep 'input_player1_b_btn' "$RA_DEV_CONF" | cut -d '"' -f 2)
BTN_X_CURR=$(grep 'input_player1_x_btn' "$RA_DEV_CONF" | cut -d '"' -f 2)
BTN_Y_CURR=$(grep 'input_player1_y_btn' "$RA_DEV_CONF" | cut -d '"' -f 2)

# Function to update button value in device specific Retroarch config
update_button_value() {
    button_name=$1
    expected_value=$2
    current_value=$3

    if [ "$current_value" -ne "$expected_value" ]; then
        sed -i "s/\($button_name = \).*/\1\"$expected_value\"/" "$RA_DEV_CONF"
        echo "Updated $button_name to $expected_value"
    fi
}

# Define both retro and modern SDL Maps
GCDB_MODERN="gamecontrollerdb_modern.txt"
GCDB_RETRO="gamecontrollerdb_retro.txt"

# Check current swap value [0] = Retro [1] = Modern
if [ -f "/run/muos/global/settings/advanced/swap" ]; then
    CTRLSWAP=$(cat "/run/muos/global/settings/advanced/swap")
else
    CTRLSWAP=0
fi

# Remove any existing SDL Map symlink

for LIB_D in lib lib32; do
if [ -f "/usr/$LIB_D/gamecontrollerdb.txt" ]; then
    rm -f "/usr/$LIB_D/gamecontrollerdb.txt"
fi

# Check which control style has been selected
if [ $CTRLSWAP -eq 0 ]; then
    echo "Retro style selected"
ln -s "/opt/muos/device/current/control/$GCDB_RETRO" "/usr/$LIB_D/gamecontrollerdb.txt"
else
    echo "Modern style selected"
ln -s "/opt/muos/device/current/control/$GCDB_MODERN" "/usr/$LIB_D/gamecontrollerdb.txt"
fi
done

# Modify retroarch config to reflect selected controller style
if [ $CTRLSWAP -eq 0 ]; then
    update_button_value "input_player1_a_btn" $BTN_A_RETRO $BTN_A_CURR
    update_button_value "input_player1_b_btn" $BTN_B_RETRO $BTN_B_CURR
    update_button_value "input_player1_x_btn" $BTN_X_RETRO $BTN_X_CURR
    update_button_value "input_player1_y_btn" $BTN_Y_RETRO $BTN_Y_CURR
else
    update_button_value "input_player1_a_btn" $BTN_A_MODERN $BTN_A_CURR
    update_button_value "input_player1_b_btn" $BTN_B_MODERN $BTN_B_CURR
    update_button_value "input_player1_x_btn" $BTN_X_MODERN $BTN_X_CURR
    update_button_value "input_player1_y_btn" $BTN_Y_MODERN $BTN_Y_CURR
fi