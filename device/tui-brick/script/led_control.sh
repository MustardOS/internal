#!/bin/sh

. /opt/muos/script/var/func.sh
[ "$(GET_VAR "global" "boot/device_mode")" -eq 1 ] && exit 0

LED_SYSFS="/sys/class/led_anim"

if [ $# -lt 8 ] || [ $# -gt 17 ]; then
	echo "Usage: $0 <led_mode 1–7> <brightness (max 60)> <left_r> <left_g> <left_b> <right_r> <right_g> <right_b> [middle_r] [middle_g] [middle_b] [f1_r] [f1_g] [f1_b] [f2_r] [f2_g] [f2_b]"
	exit 1
fi

LED_MODE=${1}
BRIGHTNESS=${2}
LEFT_RED=${3}
LEFT_GREEN=${4}
LEFT_BLUE=${5}
RIGHT_RED=${6}
RIGHT_GREEN=${7}
RIGHT_BLUE=${8}
MIDDLE_RED=${9:-0}
MIDDLE_GREEN=${10:-0}
MIDDLE_BLUE=${11:-0}
F1_RED=${12:-$LEFT_RED}
F1_GREEN=${13:-$LEFT_GREEN}
F1_BLUE=${14:-$LEFT_BLUE}
F2_RED=${15:-$RIGHT_RED}
F2_GREEN=${16:-$RIGHT_GREEN}
F2_BLUE=${17:-$RIGHT_BLUE}

# Clamp brightness to max 60
[ "$BRIGHTNESS" -gt 60 ] && BRIGHTNESS=60
[ "$BRIGHTNESS" -lt 0 ] && BRIGHTNESS=0

CLAMP_RGB() {
	RGB=$1
	[ "$RGB" -gt 255 ] && RGB=255
	[ "$RGB" -lt 0 ] && RGB=0
	printf "%d" "$RGB"
}

LEFT_RED=$(CLAMP_RGB "$LEFT_RED")
LEFT_GREEN=$(CLAMP_RGB "$LEFT_GREEN")
LEFT_BLUE=$(CLAMP_RGB "$LEFT_BLUE")

RIGHT_RED=$(CLAMP_RGB "$RIGHT_RED")
RIGHT_GREEN=$(CLAMP_RGB "$RIGHT_GREEN")
RIGHT_BLUE=$(CLAMP_RGB "$RIGHT_BLUE")

MIDDLE_RED=$(CLAMP_RGB "$MIDDLE_RED")
MIDDLE_GREEN=$(CLAMP_RGB "$MIDDLE_GREEN")
MIDDLE_BLUE=$(CLAMP_RGB "$MIDDLE_BLUE")

F1_RED=$(CLAMP_RGB "$F1_RED")
F1_GREEN=$(CLAMP_RGB "$F1_GREEN")
F1_BLUE=$(CLAMP_RGB "$F1_BLUE")

F2_RED=$(CLAMP_RGB "$F2_RED")
F2_GREEN=$(CLAMP_RGB "$F2_GREEN")
F2_BLUE=$(CLAMP_RGB "$F2_BLUE")

HEX_LEFT=$(printf "%02X%02X%02X" "$LEFT_RED" "$LEFT_GREEN" "$LEFT_BLUE")
HEX_RIGHT=$(printf "%02X%02X%02X" "$RIGHT_RED" "$RIGHT_GREEN" "$RIGHT_BLUE")
HEX_MIDDLE=$(printf "%02X%02X%02X" "$MIDDLE_RED" "$MIDDLE_GREEN" "$MIDDLE_BLUE")
HEX_F1=$(printf "%02X%02X%02X" "$F1_RED" "$F1_GREEN" "$F1_BLUE")
HEX_F2=$(printf "%02X%02X%02X" "$F2_RED" "$F2_GREEN" "$F2_BLUE")

case "$LED_MODE" in
	1) EFFECT_TYPE=2 ;; # breath
	2) EFFECT_TYPE=3 ;; # sniff
	3) EFFECT_TYPE=4 ;; # static
	4) EFFECT_TYPE=5 ;; # blink1
	5) EFFECT_TYPE=6 ;; # blink2
	6) EFFECT_TYPE=7 ;; # blink3
	7) EFFECT_TYPE=1 ;; # linear
	*)
		echo "Invalid LED mode: $LED_MODE (must be 1–7)"
		exit 1
		;;
esac

echo "$BRIGHTNESS" >"$LED_SYSFS/max_scale"

echo "$HEX_LEFT" >"$LED_SYSFS/effect_rgb_hex_l"
echo "$HEX_RIGHT" >"$LED_SYSFS/effect_rgb_hex_r"
echo "$HEX_MIDDLE" >"$LED_SYSFS/effect_rgb_hex_m"
echo "$HEX_F1" >"$LED_SYSFS/effect_rgb_hex_f1"
echo "$HEX_F2" >"$LED_SYSFS/effect_rgb_hex_f2"

for i in l r m f1 f2; do
	echo "1000" >"$LED_SYSFS/effect_duration_$i"
	echo "-1" >"$LED_SYSFS/effect_cycles_$i"
	echo "$EFFECT_TYPE" >"$LED_SYSFS/effect_$i"
done

echo 1 >"$LED_SYSFS/effect_enable"

printf "LED mode %s applied\n" "$LED_MODE"
printf "Brightness: %s\n" "$BRIGHTNESS"
printf "Left:   RGB(%s %s %s) = #%s\n" "$LEFT_RED" "$LEFT_GREEN" "$LEFT_BLUE" "$HEX_LEFT"
printf "Right:  RGB(%s %s %s) = #%s\n" "$RIGHT_RED" "$RIGHT_GREEN" "$RIGHT_BLUE" "$HEX_RIGHT"
printf "Middle: RGB(%s %s %s) = #%s\n" "$MIDDLE_RED" "$MIDDLE_GREEN" "$MIDDLE_BLUE" "$HEX_MIDDLE"
printf "F1:     RGB(%s %s %s) = #%s\n" "$F1_RED" "$F1_GREEN" "$F1_BLUE" "$HEX_F1"
printf "F2:     RGB(%s %s %s) = #%s\n" "$F2_RED" "$F2_GREEN" "$F2_BLUE" "$HEX_F2"
