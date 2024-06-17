#!/bin/sh

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.ini

DEVICE=$(tr '[:upper:]' '[:lower:]' < "/opt/muos/config/device.txt")
DEVICE_CONFIG="/opt/muos/device/$DEVICE/config.ini"

HDMI_STATE=$(parse_ini "$DEVICE_CONFIG" "screen" "hdmi")
HDMI_MODE=$(parse_ini "$CONFIG" "settings.general" "hdmi")

DISPLAY="/sys/kernel/debug/dispdbg"

FG_PROC="/tmp/fg_proc"

# Switch off HDMI
echo disp0 > $DISPLAY/name
echo switch > $DISPLAY/command
echo 1 0 > $DISPLAY/param
echo 1 > $DISPLAY/start

FG_PROC_VAL=$(cat "$FG_PROC")

if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" > /dev/null; then
	pkill -STOP "playbgm.sh"
	killall -q "mp3play"
fi

sed -i -E 's/(defaults\.(ctl|pcm)\.card) 0/\1 2/g' /usr/share/alsa/alsa.conf
alsactl kill quit

if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" > /dev/null; then
	pkill -CONT "playbgm.sh"
fi

# Reset the display
fbset -g 1280 720 1280 1440 32
fbset -g 640 480 640 960 32
fbset -g 1280 720 1280 1440 32
fbset -g 640 480 640 960 32

