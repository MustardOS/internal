#!/bin/sh

. /opt/muos/script/var/log.sh

case "$(GET_VAR "device" "board/name")" in
	tui-*) ;;
	*) exit 0 ;;
esac

[ "${1:-load}" = load ] || exit 0
[ "$(GET_VAR "config" "danger/emmc")" = 1 ] || exit 0

EMMC_MODULE=/opt/muos/device/module/tui_emmc.ko
if [ ! -f "$EMMC_MODULE" ]; then
	LOG_ERROR "$0" 0 "MODULE" "TrimUI internal storage module is missing"
	exit 1
fi

grep -q '^tui_emmc ' /proc/modules && exit 0
insmod "$EMMC_MODULE" || {
	LOG_ERROR "$0" 0 "MODULE" "Could not expose TrimUI internal storage"
	exit 1
}
