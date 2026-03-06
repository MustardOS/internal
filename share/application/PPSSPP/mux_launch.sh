#!/bin/sh
# HELP: PPSSPP
# ICON: ppsspp
# GRID: PPSSPP

. /opt/muos/script/var/func.sh

APP_BIN="PPSSPP"
SETUP_APP "$APP_BIN" ""

SETUP_STAGE_OVERLAY

# -----------------------------------------------------------------------------

PPSSPP_DIR="$MUOS_SHARE_DIR/emulator/ppsspp"

RESET_GRAPHICS_BACKEND() {
	sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
	rm -f "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/FailedGraphicsBackends.txt"
}

case "$(GET_VAR "device" "board/name")" in
	rg*) RESET_GRAPHICS_BACKEND ;;
	mgx* | tui*)
		# Prevent blackscreen due to "an issue with the ordering of the RGBA 8888 or something like that" (acmeplus 2025)
		setalpha 0

		# Keep this until we build with Vulkan
		RESET_GRAPHICS_BACKEND
		;;
esac

HOME="$PPSSPP_DIR"
export HOME

XDG_CONFIG_HOME="$HOME/.config"
export XDG_CONFIG_HOME

rm -rf "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/CACHE/"*
cd "$PPSSPP_DIR" || exit

./$APP_BIN
