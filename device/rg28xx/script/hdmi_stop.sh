#!/bin/sh

. /opt/muos/script/var/func.sh



FG_PROC_VAL=$(GET_VAR "system" "foreground_process")

if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
	pkill -STOP "playbgm.sh"
	killall -q "mpg123"
fi

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf
alsactl kill quit

echo "0" >/tmp/hdmi_in_use

if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
	pkill -CONT "playbgm.sh"
fi

# Switch off HDMI
DISPLAY_WRITE disp0 switch '1 0'

# Reset the display
fbset -g 1280 720 1280 1440 32
fbset -g 640 480 640 960 32
fbset -g 1280 720 1280 1440 32
fbset -g 640 480 640 960 32
