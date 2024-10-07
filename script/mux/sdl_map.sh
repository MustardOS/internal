#!/bin/sh

# Define RA config values for "menu_swap_ok_cancel_buttons"
RA_RETRO="false"
RA_MODERN="true"

# Define device specific Retroarch controller map
RA_DEV_CONF="/opt/muos/device/current/control/retroarch.device.cfg"


# Function to update button value in device specific Retroarch config
update_button_value() {
    button_name=$1
    expected_value=$2

    # Read current value from RA Device Config
    current_value=$(grep "^$button_name" "$RA_DEV_CONF" | cut -d '"' -f 2)

    # Update the value if it doesn't match
    if [ "$current_value" != "$expected_value" ]; then
        sed -i "s|\($button_name = \).*\$|\1\"$expected_value\"|" "$RA_DEV_CONF"
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
    update_button_value "menu_swap_ok_cancel_buttons" $RA_RETRO
else
    update_button_value "menu_swap_ok_cancel_buttons" $RA_MODERN
fi
