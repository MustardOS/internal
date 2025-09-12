#!/bin/sh
# HELP: PPSSPP
# ICON: ppsspp
# GRID: PPSSPP

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

SETUP_SDL_ENVIRONMENT

PPSSPP_DIR="/opt/muos/share/emulator/ppsspp"

case "$(GET_VAR "device" "board/name")" in
	rg*)
		sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' \
			"$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

		rm -f "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/FailedGraphicsBackends.txt"
		;;
	tui*)
		# Prevent blackscreen due to "an issue with the ordering of the RGBA 8888 or something like that" (acmeplus 2025)
		setalpha 0

		# Keep this until we build with Vulkan
		sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' \
			"$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

		rm -f "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/FailedGraphicsBackends.txt"
		;;
esac

HOME="$PPSSPP_DIR"
export HOME

XDG_CONFIG_HOME="$HOME/.config"
export XDG_CONFIG_HOME

rm -rf "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/CACHE/"*
cd "$PPSSPP_DIR" || exit

SET_VAR "system" "foreground_process" "PPSSPP"

./PPSSPP

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
