#!/bin/sh
# HELP: Restore the default MustardOS hotkeys.
# ICON: sdcard

. /opt/muos/script/var/func.sh

FRONTEND stop

echo "Restoring MustardOS Hotkeys"

# Define paths to hotkey files
RG_INI="$MUOS_SHARE_DIR/hotkey/rg.ini"
TUI_INI="$MUOS_SHARE_DIR/hotkey/tui.ini"

# Replace rg.ini with defaults
cat > "$RG_INI" << 'EOF'
0=["R2","L2","A"]
1=["R2","L2","X"]
2=["L1","MENU_LONG","A"]
3=["L1","MENU_LONG","X"]
4=["MENU_LONG","START"]
5=["MENU_LONG","SELECT"]
EOF

# Replace tui.ini with defaults
cat > "$TUI_INI" << 'EOF'
0=["R2","L2","A"]
1=["R2","L2","X"]
2=["L1","MENU_SHORT","A"]
3=["L1","MENU_SHORT","X"]
4=["MENU_SHORT","START"]
5=["MENU_SHORT","SELECT"]
EOF

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0