#!/bin/sh

. /opt/muos/script/var/func.sh

for INIT in audio battery cpu board input input/dpad input/analog/left input/analog/right input/button mux network screen sdl storage/boot storage/rom storage/root storage/sdcard storage/usb; do
	case $INIT in
		"audio") VARS="platform object control channel min max" ;;
		"battery") VARS="capacity health voltage charger" ;;
		"cpu") VARS="cores default governor scaler sampling_rate up_threshold sampling_down_factor io_is_busy sampling_rate_default up_threshold_default sampling_down_factor_default io_is_busy_default" ;;
		"board") VARS="name home network bluetooth portmaster lid hdmi event debugfs rtc led" ;;
		"input") VARS="ev0 ev1 axis_min axis_max" ;;
		"input/dpad") VARS="up down left right" ;;
		"input/analog/left") VARS="up down left right click" ;;
		"input/analog/right") VARS="up down left right click" ;;
		"input/button") VARS="a b c x y z l1 l2 l3 r1 r2 r3 menu_short menu_long select start power_short power_long vol_up vol_down" ;;
		"mux") VARS="width height item_count item_height item_panel item_prev_low item_prev_high item_next_low item_next_high" ;;
		"network") VARS="module name type iface state" ;;
		"screen") VARS="device hdmi bright buffer width height rotate wait" ;;
		"sdl") VARS="scaler rotation blitter_disabled" ;;
		"storage/boot") VARS="dev num sep mount type" ;;
		"storage/rom") VARS="dev num sep mount type" ;;
		"storage/root") VARS="dev num sep mount type" ;;
		"storage/sdcard") VARS="dev num sep mount type" ;;
		"storage/usb") VARS="dev num sep mount type" ;;
	esac
	GEN_VAR "$(basename "$0" .sh)" "$INIT" "$VARS"
done
