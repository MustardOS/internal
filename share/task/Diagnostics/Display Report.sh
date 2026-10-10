#!/bin/sh
# HELP: Display Report - Checks the panel, framebuffer, backlight, HDMI and screen settings, then saves a report to SD1
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "display_report" "Display Report"

DIAG_SECTION "muOS screen configuration"
DIAG_CONFIG "$MUOS_CONF_DEVICE/screen"
DIAG_CONFIG "$MUOS_CONF_DEVICE/sdl"
DIAG_KV "Brightness setting" "$(GET_VAR "config" "settings/general/brightness" 2>/dev/null)"
DIAG_KV "HDMI mode flag" "$(DIAG_READ "$MUOS_RUN_DIR/hdmi_mode")"

DIAG_SECTION "Framebuffers"
FB_COUNT=0
for FB in /sys/class/graphics/fb[0-9]*; do
	[ -d "$FB" ] || continue
	FB_COUNT=$((FB_COUNT + 1))
	DIAG_OUT "-- $(basename "$FB")"
	DIAG_ATTRS "$FB"
	[ "$(DIAG_READ "$FB/blank")" = "4" ] && DIAG_FINDING "DISPLAY" "$(basename "$FB") is blanked (powered down)."
done
[ "$FB_COUNT" -eq 0 ] && DIAG_FINDING "KERNEL" "There is no framebuffer device."
DIAG_CMD "fbset" fbset -s

DIAG_SECTION "DRM connectors"
for CONNECTOR in /sys/class/drm/card*-*; do
	[ -d "$CONNECTOR" ] || continue
	DIAG_OUT "-- $(basename "$CONNECTOR")"
	for ATTR in status enabled dpms; do
		DIAG_KV "   $ATTR" "$(DIAG_READ "$CONNECTOR/$ATTR")"
	done
	DIAG_KV "   modes" "$(DIAG_READ "$CONNECTOR/modes" | tr '\n' ' ')"
	case "$(basename "$CONNECTOR")" in
		*HDMI*)
			if [ "$(DIAG_READ "$CONNECTOR/status")" = "connected" ] && [ ! -e "$MUOS_RUN_DIR/hdmi_mode" ]; then
				DIAG_FINDING "HDMI" "An HDMI display is connected but muOS is not in HDMI mode."
			fi
			;;
	esac
done

DIAG_SECTION "Backlight"
BACKLIGHTS=0
for BL in /sys/class/backlight/*; do
	[ -d "$BL" ] || continue
	BACKLIGHTS=$((BACKLIGHTS + 1))
	DIAG_OUT "-- $(basename "$BL")"
	DIAG_ATTRS "$BL"
	LEVEL=$(DIAG_READ "$BL/brightness")
	POWER=$(DIAG_READ "$BL/bl_power")
	DIAG_IS_NUM "$LEVEL" && [ "$LEVEL" -eq 0 ] && [ ! -e "$MUOS_RUN_DIR/hdmi_mode" ] &&
		DIAG_FINDING "DISPLAY" "The backlight $(basename "$BL") is at 0, so the screen will look black."
	DIAG_IS_NUM "$POWER" && [ "$POWER" -ne 0 ] &&
		DIAG_FINDING "DISPLAY" "The backlight $(basename "$BL") is powered off (bl_power $POWER)."
done
[ "$BACKLIGHTS" -eq 0 ] && DIAG_OUT "No backlight class device (this board drives brightness another way)"

DIAG_SECTION "Kernel messages"
DIAG_DMESG "drm|panel|dsi|lcd|fb[0-9]|framebuffer|hdmi|disp|backlight|pwm|mipi|vop|de2" 80

DIAG_FINISH "Display report saved"
exit 0
