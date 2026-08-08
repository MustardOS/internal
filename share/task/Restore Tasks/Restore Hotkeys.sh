#!/bin/sh
# HELP: Restore the default MustardOS hotkeys.
# ICON: sdcard
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "restore_hotkeys" "Restore Hotkeys"


TASK_STATUS "Restoring MustardOS Hotkeys"

# Define paths to hotkey files
RG_INI="$MUOS_SHARE_DIR/hotkey/rg.ini"
TUI_INI="$MUOS_SHARE_DIR/hotkey/tui.ini"

# Replace rg.ini with defaults
cat > "$RG_INI" << 'EOF'
0=["R2","L2","A"]
1=["R2","L2","X"]
2=["L1","MENU","A"]
3=["L1","MENU","X"]
4=["MENU","START"]
5=["MENU","SELECT"]
EOF

# Replace tui.ini with defaults
cat > "$TUI_INI" << 'EOF'
0=["R2","L2","A"]
1=["R2","L2","X"]
2=["L1","MENU","A"]
3=["L1","MENU","X"]
4=["MENU","START"]
5=["MENU","SELECT"]
EOF

TASK_STATUS "Sync Filesystem"
sync

TASK_COMPLETE "Hotkeys restored"

exit 0