#!/bin/sh

. /opt/muos/script/var/log.sh

[ "${1:-load}" = load ] || exit 0
[ "$(GET_VAR "config" "danger/emmc")" = 1 ] || exit 0

case "$(GET_VAR "device" "board/name")" in
	rg-vita-pro)
		[ -b /dev/mmcblk0 ] || {
			LOG_ERROR "$0" 0 "STORAGE" "Vita Pro internal eMMC was not found"
			exit 1
		}
		LOG_INFO "$0" 0 "STORAGE" "Vita Pro internal storage available at /dev/mmcblk0"
		exit 0
		;;
	tui-*)
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
		;;
	*) exit 0 ;;
esac
