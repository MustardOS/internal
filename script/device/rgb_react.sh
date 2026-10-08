#!/bin/sh
# rgb_react.sh - Screen reactive RGB lighting
#
# Samples the framebuffer and drives the RGB sticks to match the on-screen
# colour. Runs while the RGB mode is set to Screen React and exits otherwise,
# so it is (re)started by "murgb restore" and left alone by every other mode.

. /opt/muos/script/var/func.sh

# Behaviour
SCREEN_REACT_MODE=10  # settings/rgb/mode value that enables Screen React

# Sampling
FB_DEVICE="/dev/fb0"
MARGIN_PERCENT=20     # ignored screen border per side (0-50)
GRID_LONG_SIDE=5      # sample points along the long edge (4-6)
SATURATION_BOOST=250  # dull colour boost (100: none, 200: 2x)
SAMPLE_INTERVAL_MS=333
FRAME_INTERVAL_MS=33

# LED hardware
LED_SYSFS="/sys/class/led_anim"
LED_JOYPAD="/sys/devices/platform/singleadc-joypad"
SERIAL_DEVICE="/dev/ttyS5"
MCU_PWR="/sys/class/power_supply/axp2202-battery/mcu_pwr"

BACKEND=""
SERIAL_READY=0

DETECT_BACKEND() {
	case "$(GET_VAR "config" "settings/rgb/backend")" in
		1) BACKEND="SYSFS" && return ;;
		2) BACKEND="SERIAL" && return ;;
		3) BACKEND="JOYPAD" && return ;;
	esac

	if [ -d "$LED_JOYPAD" ] && [ -w "$LED_JOYPAD/led_set" ]; then
		BACKEND="JOYPAD"
	elif [ -d "$LED_SYSFS" ]; then
		BACKEND="SYSFS"
	elif [ -c "$SERIAL_DEVICE" ]; then
		BACKEND="SERIAL"
	fi
}

SYSFS_WRITE() {
	[ -w "$LED_SYSFS/$1" ] && printf "%s\n" "$2" >"$LED_SYSFS/$1"
}

UPDATE_SYSFS() {
	# $1 brightness 0-255, $2-4 left RGB, $5-7 right RGB
	HEX_L=$(printf "%02X%02X%02X " "$2" "$3" "$4")
	HEX_R=$(printf "%02X%02X%02X " "$5" "$6" "$7")

	SYSFS_WRITE "max_scale" "$(($1 * 60 / 255))"

	if [ "$HEX_L" = "$HEX_R" ] && [ -w "$LED_SYSFS/effect_rgb_hex_lr" ]; then
		SYSFS_WRITE "effect_rgb_hex_lr" "$HEX_L"
	else
		SYSFS_WRITE "effect_rgb_hex_l" "$HEX_L"
		SYSFS_WRITE "effect_rgb_hex_r" "$HEX_R"
	fi

	if [ -w "$LED_SYSFS/effect_lr" ]; then
		SYSFS_WRITE "effect_lr" "4"
	else
		SYSFS_WRITE "effect_l" "4"
		SYSFS_WRITE "effect_r" "4"
	fi

	SYSFS_WRITE "effect_enable" "1"
}

SERIAL_PREPARE() {
	[ -w "$MCU_PWR" ] && printf "1\n" >"$MCU_PWR"
	stty -F "$SERIAL_DEVICE" 115200 cs8 -parenb -cstopb -opost -isig -icanon -echo 2>/dev/null
	SERIAL_READY=1
}

UPDATE_SERIAL() {
	# $1 brightness 0-255, $2-4 left RGB, $5-7 right RGB
	[ "$SERIAL_READY" -eq 1 ] || SERIAL_PREPARE

	BRI=$1
	LR=$2 LG=$3 LB=$4
	RR=$5 RG=$6 RB=$7

	set -- 1 "$BRI"
	I=0 && while [ "$I" -lt 8 ]; do set -- "$@" "$RR" "$RG" "$RB" && I=$((I + 1)); done
	I=0 && while [ "$I" -lt 8 ]; do set -- "$@" "$LR" "$LG" "$LB" && I=$((I + 1)); done

	SUM=0 && for B in "$@"; do SUM=$(((SUM + B) & 255)); done

	printf "%b" "$(printf '\\x%02X' "$@" "$SUM")" >"$SERIAL_DEVICE"
}

UPDATE_JOYPAD() {
	# TODO: joypad backend (rg-vita-pro) via $LED_JOYPAD - stubbed for now.
	:
}

UPDATE_LEDS() {
	case "$BACKEND" in
		SYSFS) UPDATE_SYSFS "$@" ;;
		SERIAL) UPDATE_SERIAL "$@" ;;
		JOYPAD) UPDATE_JOYPAD "$@" ;;
	esac
}

BOOST_COLOUR() {
	# $1-3 weighted RGB sums, $4 total weight -> BR BG BB (boosted, clamped)
	if [ "$4" -le 0 ]; then
		BR=0 BG=0 BB=0
		return
	fi

	AR=$(($1 / $4)) AG=$(($2 / $4)) AB=$(($3 / $4))

	MAX=$AR && [ "$AG" -gt "$MAX" ] && MAX=$AG
	[ "$AB" -gt "$MAX" ] && MAX=$AB
	MIN=$AR && [ "$AG" -lt "$MIN" ] && MIN=$AG
	[ "$AB" -lt "$MIN" ] && MIN=$AB

	if [ "$MAX" -gt 0 ]; then
		SAT=$(((MAX - MIN) * 100 / MAX))
	else
		SAT=0
	fi

	# Only boost dull colours, leave already vivid ones alone
	BOOST=$((100 + (100 - SAT) * (SATURATION_BOOST - 100) / 100))
	GRAY=$(((AR + AG + AB) / 3))

	BR=$((GRAY + (AR - GRAY) * BOOST / 100))
	BG=$((GRAY + (AG - GRAY) * BOOST / 100))
	BB=$((GRAY + (AB - GRAY) * BOOST / 100))

	[ "$BR" -lt 0 ] && BR=0
	[ "$BR" -gt 255 ] && BR=255
	[ "$BG" -lt 0 ] && BG=0
	[ "$BG" -gt 255 ] && BG=255
	[ "$BB" -lt 0 ] && BB=0
	[ "$BB" -gt 255 ] && BB=255
}

SAMPLE() {
	# Read a staggered grid of pixels and set the TARGET colours. Vivid pixels
	# carry more weight; sides are split for dual stick devices.
	COL_SPACING=$((SAMPLE_W / GRID_W))
	HALF_SPACING=$((COL_SPACING / 2))
	QUARTER_SPACING=$((HALF_SPACING / 2))

	WR=0 WG=0 WB=0 WT=0
	WR_L=0 WG_L=0 WB_L=0 WT_L=0
	WR_R=0 WG_R=0 WB_R=0 WT_R=0

	ROW=0
	while [ "$ROW" -lt "$GRID_H" ]; do
		PY=$((MARGIN_H + ROW * SAMPLE_H / GRID_H + SAMPLE_H / (GRID_H * 2)))

		COL=0
		while [ "$COL" -lt "$GRID_W" ]; do
			PX=$((MARGIN_W + COL * COL_SPACING + HALF_SPACING))
			if [ "$((ROW % 2))" -eq 1 ]; then
				PX=$((PX - QUARTER_SPACING))
			else
				PX=$((PX + QUARTER_SPACING))
			fi

			# Framebuffer is BGRA (4 bytes per pixel)
			OFFSET=$(((PY * FB_WIDTH + PX) * 4))
			set -- $(dd if="$FB_DEVICE" bs=1 skip="$OFFSET" count=4 2>/dev/null | od -An -tu1)
			B=$1 G=$2 R=$3

			MAX=$R && [ "$G" -gt "$MAX" ] && MAX=$G
			[ "$B" -gt "$MAX" ] && MAX=$B
			MIN=$R && [ "$G" -lt "$MIN" ] && MIN=$G
			[ "$B" -lt "$MIN" ] && MIN=$B

			if [ "$MAX" -gt 0 ]; then
				W=$(((MAX - MIN) * 100 / MAX))
				[ "$W" -lt 1 ] && W=1
			else
				W=1
			fi

			if [ "$STICK_COUNT" -eq 1 ]; then
				WR=$((WR + R * W)) WG=$((WG + G * W)) WB=$((WB + B * W)) WT=$((WT + W))
			elif [ "$PX" -lt "$HALF_WIDTH" ]; then
				WR_L=$((WR_L + R * W)) WG_L=$((WG_L + G * W)) WB_L=$((WB_L + B * W)) WT_L=$((WT_L + W))
			else
				WR_R=$((WR_R + R * W)) WG_R=$((WG_R + G * W)) WB_R=$((WB_R + B * W)) WT_R=$((WT_R + W))
			fi

			COL=$((COL + 1))
		done
		ROW=$((ROW + 1))
	done

	if [ "$STICK_COUNT" -eq 1 ]; then
		BOOST_COLOUR "$WR" "$WG" "$WB" "$WT"
		TARGET_RL=$BR TARGET_GL=$BG TARGET_BL=$BB
		TARGET_RR=$BR TARGET_GR=$BG TARGET_BR=$BB
	else
		BOOST_COLOUR "$WR_L" "$WG_L" "$WB_L" "$WT_L"
		TARGET_RL=$BR TARGET_GL=$BG TARGET_BL=$BB
		BOOST_COLOUR "$WR_R" "$WG_R" "$WB_R" "$WT_R"
		TARGET_RR=$BR TARGET_GR=$BG TARGET_BR=$BB
	fi
}

SMOOTH() {
	# $1 current, $2 target -> SM (moves current one step toward target)
	SM_DIFF=$(($2 - $1))
	SM_STEP=$((SM_DIFF * SMOOTHING / 100))
	[ "$SM_DIFF" -gt 0 ] && [ "$SM_STEP" -eq 0 ] && SM_STEP=1
	[ "$SM_DIFF" -lt 0 ] && [ "$SM_STEP" -eq 0 ] && SM_STEP=-1
	SM=$(($1 + SM_STEP))
}

NOW_MS() {
	read -r UP _ </proc/uptime
	FRAC=${UP#*.} && FRAC=${FRAC#0}
	NOW=$((${UP%.*} * 1000 + ${FRAC:-0} * 10))
}

# Single instance: murgb may (re)launch us on every restore
PID_FILE="$MUOS_RUN_DIR/rgb_react.pid"
OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
[ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ] && kill -0 "$OLD_PID" 2>/dev/null && exit 0
echo "$$" >"$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT INT TERM

# Nothing to do without RGB sticks
[ "$(GET_VAR "device" "led/rgb")" -eq 1 ] || exit 0
[ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ] || exit 0

STICK_COUNT=$(GET_VAR "device" "board/stick")
[ -z "$STICK_COUNT" ] && STICK_COUNT=2
[ "$STICK_COUNT" -eq 0 ] && exit 0

DETECT_BACKEND
[ -z "$BACKEND" ] && exit 0
[ "$BACKEND" = "JOYPAD" ] && exit 0

set -- $(fbset | awk '/geometry/ { print $2, $3 }')
FB_WIDTH=$1 FB_HEIGHT=$2
[ -z "$FB_WIDTH" ] && exit 0

# Sampling grid keeps the aspect ratio, minimum 3 per side
if [ "$FB_WIDTH" -ge "$FB_HEIGHT" ]; then
	GRID_W=$GRID_LONG_SIDE
	GRID_H=$((FB_HEIGHT * GRID_LONG_SIDE / FB_WIDTH))
	[ "$GRID_H" -lt 3 ] && GRID_H=3
else
	GRID_H=$GRID_LONG_SIDE
	GRID_W=$((FB_WIDTH * GRID_LONG_SIDE / FB_HEIGHT))
	[ "$GRID_W" -lt 3 ] && GRID_W=3
fi

MARGIN_W=$((FB_WIDTH * MARGIN_PERCENT / 100))
MARGIN_H=$((FB_HEIGHT * MARGIN_PERCENT / 100))
SAMPLE_W=$((FB_WIDTH - MARGIN_W * 2))
SAMPLE_H=$((FB_HEIGHT - MARGIN_H * 2))
HALF_WIDTH=$((FB_WIDTH / 2))

# Reach the target colour by the next sample for smooth transitions
FRAMES=$((SAMPLE_INTERVAL_MS / FRAME_INTERVAL_MS))
if [ "$FRAMES" -gt 1 ]; then
	SMOOTHING=$((370 / FRAMES))
	[ "$SMOOTHING" -lt 10 ] && SMOOTHING=10
	[ "$SMOOTHING" -gt 50 ] && SMOOTHING=50
else
	SMOOTHING=50
fi

CURR_RL=0 CURR_GL=0 CURR_BL=0
CURR_RR=0 CURR_GR=0 CURR_BR=0
TARGET_RL=0 TARGET_GL=0 TARGET_BL=0
TARGET_RR=0 TARGET_GR=0 TARGET_BR=0
BRIGHT=153
NEXT_SAMPLE=0
PAUSED=0

while :; do
	NOW_MS
	LOOP_START=$NOW

	[ "$(GET_VAR "config" "settings/general/rgb")" -eq 1 ] || exit 0
	[ "$(GET_VAR "config" "settings/rgb/mode")" = "$SCREEN_REACT_MODE" ] || exit 0

	# Stand down only when muOS blanks the LEDs on idle/dim (it does the same
	# to every RGB mode). IDLE_STATE, not the stale IS_IDLE, is cleared again
	# on resume. Low battery is left alone: like every other mode we keep
	# reacting, and muOS's dedicated power LED is the warning.
	IDLE=0
	[ -r "$IDLE_STATE" ] && read -r IDLE <"$IDLE_STATE"
	if [ "$IDLE" = "1" ]; then
		[ "$PAUSED" -eq 1 ] || { UPDATE_LEDS 0 0 0 0 0 0 0; PAUSED=1; }
		sleep 1
		continue
	fi

	# Resuming after a pause: muOS briefly wakes then re-idles on the first
	# input after dimming, so confirm the wake is sustained before reacting
	# again - otherwise the sticks would flash for a single frame.
	if [ "$PAUSED" -eq 1 ]; then
		sleep 0.2
		IDLE=0
		[ -r "$IDLE_STATE" ] && read -r IDLE <"$IDLE_STATE"
		[ "$IDLE" = "1" ] && continue
		PAUSED=0
	fi

	[ -r "$FB_DEVICE" ] || { sleep 1 && continue; }

	if [ "$NOW" -ge "$NEXT_SAMPLE" ]; then
		BRIGHT=$(GET_VAR "config" "settings/rgb/bright")
		[ -z "$BRIGHT" ] && BRIGHT=153
		SAMPLE
		NEXT_SAMPLE=$((NOW + SAMPLE_INTERVAL_MS))
	fi

	SMOOTH "$CURR_RL" "$TARGET_RL" && CURR_RL=$SM
	SMOOTH "$CURR_GL" "$TARGET_GL" && CURR_GL=$SM
	SMOOTH "$CURR_BL" "$TARGET_BL" && CURR_BL=$SM
	SMOOTH "$CURR_RR" "$TARGET_RR" && CURR_RR=$SM
	SMOOTH "$CURR_GR" "$TARGET_GR" && CURR_GR=$SM
	SMOOTH "$CURR_BR" "$TARGET_BR" && CURR_BR=$SM

	UPDATE_LEDS "$BRIGHT" "$CURR_RL" "$CURR_GL" "$CURR_BL" "$CURR_RR" "$CURR_GR" "$CURR_BR"

	NOW_MS
	SLEEP_MS=$((FRAME_INTERVAL_MS - (NOW - LOOP_START)))
	[ "$SLEEP_MS" -lt 10 ] && SLEEP_MS=10
	sleep "$((SLEEP_MS / 1000)).$(printf "%03d" "$((SLEEP_MS % 1000))")"
done
