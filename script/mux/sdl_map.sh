#!/bin/sh

GCDB_X="gamecontrollerdb_xbox.txt"
GCDB="gamecontrollerdb.txt"
if [ -f "/run/muos/global/settings/advanced/swap" ]; then
	CTRLSWAP=$(cat "/run/muos/global/settings/advanced/swap")
else
	CTRLSWAP=0
fi
for LIB_D in lib lib32; do
if [ -f "/usr/$LIB_D/$GCDB" ]; then
	rm -f "/usr/$LIB_D/$GCDB"
fi

# Check if user have requested controls be swapped to Xbox style
if [ $CTRLSWAP -eq 0 ]; then
	ln -s "/opt/muos/device/current/control/$GCDB" "/usr/$LIB_D/$GCDB" &
else
	ln -s "/opt/muos/device/current/control/$GCDB_X" "/usr/$LIB_D/$GCDB" &
fi
done