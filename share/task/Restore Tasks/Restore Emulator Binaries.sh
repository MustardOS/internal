#!/bin/sh
# HELP: Checks RetroArch, PPSSPP and ScummVM against the versions shipped for this device and reinstalls any that differ. Use this if one of them will not start or seems damaged.
# ICON: retroarch
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/base.sh
. /opt/muos/script/var/ui.sh
. /opt/muos/script/var/emulator.sh

TASK_BEGIN "restore_emulator_binaries" "Restore Emulator Binaries"

EMU_VER=$(EMULATOR_VARIANT)
if [ -z "$EMU_VER" ]; then
	TASK_ERROR 1 "This device has no bundled emulator binaries"
	exit 1
fi

TASK_STATUS "Checking and Restoring Emulators"
if ! INSTALL_EMULATORS "$EMU_VER"; then
	TASK_ERROR 1 "One or more emulators could not be restored"
	exit 1
fi

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Emulator binaries checked and restored"

exit 0
