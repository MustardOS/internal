#!/bin/sh

. /opt/muos/script/var/func.sh

MUOS_TASK_DIR="$MUOS_SHARE_DIR/task"

TASK_8188="$MUOS_TASK_DIR/Network Tasks/Enable Wi-Fi (8188eu).sh"
TASK_SD2_MOUNT="$MUOS_TASK_DIR/Storage Tasks/Mount Secondary Storage.sh"
TASK_SD2_EJECT="$MUOS_TASK_DIR/Storage Tasks/Eject Secondary Storage.sh"

case "$(GET_VAR "device" "board/name")" in
	rg28xx-h | rg35xx-2024) ;;
	rg*) rm -f "$TASK_8188" ;;
	tui*) rm -f "$TASK_8188" "$TASK_SD2_MOUNT" "$TASK_SD2_EJECT" ;;
	*) ;;
esac
