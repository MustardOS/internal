#!/bin/sh

DISPLAY="/sys/kernel/debug/dispdbg"

FG_PROC="/tmp/fg_proc"

FG_PROC_VAL=$(cat "$FG_PROC")

if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
	pkill -STOP "playbgm.sh"
	killall -q "mp3play"
fi

sed -i -E "s/(defaults\.(ctl|pcm)\.card) [0-9]+/\1 0/g" /usr/share/alsa/alsa.conf
alsactl kill quit

echo "0" >/tmp/hdmi_in_use

if [ "${FG_PROC_VAL#mux}" != "$FG_PROC_VAL" ] && pgrep -f "playbgm.sh" >/dev/null; then
	pkill -CONT "playbgm.sh"
fi

# Switch off HDMI
echo disp0 >$DISPLAY/name
echo switch >$DISPLAY/command
echo 1 0 >$DISPLAY/param
echo 1 >$DISPLAY/start

# Reset the display
fbset -g 1280 720 1280 1440 32
fbset -g 640 480 640 960 32
fbset -g 1280 720 1280 1440 32
fbset -g 640 480 640 960 32
