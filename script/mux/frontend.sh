#!/bin/sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/global/setting_advanced.sh
. /opt/muos/script/var/global/setting_general.sh
. /opt/muos/script/var/global/network.sh

ACT_GO=/tmp/act_go
APP_GO=/tmp/app_go
ASS_GO=/tmp/ass_go
ROM_GO=/tmp/rom_go

EX_CARD=/tmp/explore_card

SND_PIPE=/tmp/muplay_pipe

MUX_RELOAD=/tmp/mux_reload
MUX_AUTH=/tmp/mux_auth

echo "$GC_GEN_STARTUP" > $ACT_GO
echo "root" > $EX_CARD

KILL_BGM() {
	if pgrep -f "playbgm.sh" > /dev/null; then
		killall -q "playbgm.sh"
		killall -q "mp3play"
	fi
}

KILL_SND() {
	if pgrep -f "muplay" > /dev/null; then
		kill -9 "muplay"
		rm "$SND_PIPE"
	fi
}

until mount | grep -q "$DC_STO_ROM_MOUNT"; do
	sleep 0.25
done

if [ "$GC_ADV_RANDOM_THEME" -eq 1 ]; then
	/opt/muos/script/mux/theme.sh "?R"
fi

LAST_PLAY="/opt/muos/config/lastplay.txt"

if [ "$GC_GEN_STARTUP" = last ] || [ "$GC_GEN_STARTUP" = resume ]; then
	if [ -s "$LAST_PLAY" ]; then
		if [ "$GC_NET_ENABLED" -eq 1 ] && [ "$GC_ADV_RETROWAIT" -eq 1 ]; then
			NET_CONNECTED="/tmp/net_connected"
			OIP=0
			while true; do
				NW_MSG=$(cat <<EOF
Waiting for network to connect... ($OIP)

Press START to continue loading
Press SELECT to go to main menu
EOF
				)
				/opt/muos/extra/muxstart "$NW_MSG"
				OIP=$((OIP + 1))
				if [ "$(cat "$NET_CONNECTED")" -eq 1 ]; then
					/opt/muos/extra/muxstart "Network connected... Booting content!"
					break
				fi
				if [ "$(cat "$NET_CONNECTED")" -eq 2 ]; then
					/opt/muos/extra/muxstart "Ignoring network connection... booting content!"
					break
				fi
				if [ "$(cat "$NET_CONNECTED")" -eq 3 ]; then
					/opt/muos/extra/muxstart "Booting to main menu!"
					break
				fi
				sleep 1
			done
		fi
		if [ "$(cat "$NET_CONNECTED")" -eq 1 ] || [ "$(cat "$NET_CONNECTED")" -eq 2 ] || [ "$GC_NET_ENABLED" -eq 0 ] || [ "$GC_ADV_RETROWAIT" -eq 0 ]; then
			cat "$LAST_PLAY" > "$ROM_GO"
			/opt/muos/script/mux/launch.sh
		fi
	fi
	echo launcher > $ACT_GO
fi

while true; do
	. /opt/muos/script/var/global/setting_advanced.sh
	. /opt/muos/script/var/global/setting_general.sh

	# Background Music
	if [ "$GC_GEN_BGM" -eq 1 ] && ! pgrep -f "playbgm.sh" > /dev/null; then
		/opt/muos/script/mux/playbgm.sh
	else
		KILL_BGM
	fi

	# Navigation Sounds
	if [ "$GC_GEN_SOUND" -eq 1 ] && ! pgrep -f "muplay" > /dev/null; then
		mkfifo "$SND_PIPE"
		/opt/muos/bin/muplay "$SND_PIPE" &
	else
		KILL_SND
	fi

	# Core Association
	if [ -s "$ASS_GO" ]; then
		ROM_DIR=$(sed -n '1p' "$ASS_GO")
		ROM_SYS=$(sed -n '2p' "$ASS_GO")

		rm "$ASS_GO"
		echo "assign" > $ACT_GO
	fi

	# Content Loader
	if [ -s "$ROM_GO" ]; then
		/opt/muos/script/mux/launch.sh
	fi

	# Application Loader
	if [ -s "$APP_GO" ]; then
		. "$(cat $APP_GO)"
		rm "$APP_GO"
	fi

	# Get Last ROM Index
	if [ "$(cat $ACT_GO)" = explore ] || [ "$(cat $ACT_GO)" = favourite ] || [ "$(cat $ACT_GO)" = history ]; then
		if [ -s "/tmp/idx_go" ]; then
			LAST_INDEX_ROM=$(cat "/tmp/idx_go")
			rm "/tmp/idx_go"
		else
			LAST_INDEX_ROM=0
		fi
	fi

	# Kill PortMaster GPTOKEYB just in case!
	killall -q gptokeyb.armhf gptokeyb.aarch64

	# muX Programs
	if [ -s "$ACT_GO" ]; then
		case "$(cat $ACT_GO)" in
			"launcher")
				echo launcher > $ACT_GO
				if [ -s "$MUX_AUTH" ]; then
					rm "$MUX_AUTH"
				fi
				echo "muxlaunch" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxlaunch
				;;
			"assign")
				echo explore > $ACT_GO
				echo "$LAST_INDEX_SYS" > /tmp/lisys
				echo "muxassign" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxassign -a 0 -d "$ROM_DIR" -s "$ROM_SYS"
				;;
			"explore")
				MODULE=$(sed -n '1p' "$EX_CARD")
				echo launcher > $ACT_GO
				echo "$LAST_INDEX_SYS" > /tmp/lisys
				echo "muxassign" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxassign -a 1 -d "$(cat /tmp/explore_dir)" -s none
				echo "muxplore" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxplore -i "$LAST_INDEX_ROM" -m "$MODULE"
				;;
			"app")
				echo launcher > $ACT_GO
				if [ "$GC_ADV_LOCK" -eq 1 ]; then
					echo "muxpass" > /tmp/fg_proc
						nice --20 /opt/muos/extra/muxpass -t launch
					if [ "$?" = 1 ]; then
						echo "muxapp" > /tmp/fg_proc
						nice --20 /opt/muos/extra/muxapp
					fi
				else
					echo "muxapp" > /tmp/fg_proc
					nice --20 /opt/muos/extra/muxapp
				fi
				;;
			"config")
				echo launcher > $ACT_GO
				if [ "$GC_ADV_LOCK" -eq 1 ]; then
					if [ -e "$MUX_AUTH" ]; then
						echo "muxconfig" > /tmp/fg_proc
						nice --20 /opt/muos/extra/muxconfig
					else
						echo "muxpass" > /tmp/fg_proc
						nice --20 /opt/muos/extra/muxpass -t setting
						if [ "$?" = 1 ]; then
							echo "muxconfig" > /tmp/fg_proc
							nice --20 /opt/muos/extra/muxconfig
							touch "$MUX_AUTH"
						fi
					fi
				else
					echo "muxconfig" > /tmp/fg_proc
					nice --20 /opt/muos/extra/muxconfig
				fi
				;;
			"info")
				echo launcher > $ACT_GO
				echo "muxinfo" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxinfo
				;;
			"tweakgen")
				echo config > $ACT_GO
				echo "muxtweakgen" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxtweakgen
				;;
			"tweakadv")
				echo tweakgen > $ACT_GO
				echo "muxtweakadv" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxtweakadv
				;;
			"theme")
				echo config > $ACT_GO
				echo "muxtheme" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxtheme
				;;
			"visual")
				echo tweakgen > $ACT_GO
				echo "muxvisual" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxvisual
				;;
			"net_profile")
				echo network > $ACT_GO
				echo "muxnetprofile" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxnetprofile
				;;
			"net_scan")
				echo network > $ACT_GO
				echo "muxnetscan" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxnetscan
				;;
			"network")
				echo config > $ACT_GO
				echo "muxnetwork" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxnetwork
				;;
			"webserv")
				echo config > $ACT_GO
				echo "muxwebserv" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxwebserv
				;;
			"rtc")
				echo config > $ACT_GO
				echo "muxrtc" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxrtc
				;;
			"timezone")
				echo rtc > $ACT_GO
				echo "muxtimezone" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxtimezone
				;;
			"tester")
				echo info > $ACT_GO
				echo "muxtester" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxtester
				;;
			"device")
				echo config > $ACT_GO
				echo "muxdevice" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxdevice
				;;
			"system")
				echo info > $ACT_GO
				echo "muxsysinfo" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxsysinfo
				;;
			"favourite")
				find "$DC_STO_ROM_MOUNT"/MUOS/info/favourite -maxdepth 1 -type f -size 0 -delete
				echo launcher > $ACT_GO
				echo "muxplore" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxplore -i "$LAST_INDEX_ROM" -m favourite
				if [ -s "$MUX_RELOAD" ]; then
					if [ "$(cat $MUX_RELOAD)" -eq 1 ]; then
						echo favourite > $ACT_GO
					fi
					rm "$MUX_RELOAD"
				fi
				;;
			"history")
				find "$DC_STO_ROM_MOUNT"/MUOS/info/history -maxdepth 1 -type f -size 0 -delete
				echo launcher > $ACT_GO
				echo "muxplore" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxplore -i 0 -m history
				if [ -s "$MUX_RELOAD" ]; then
					if [ "$(cat $MUX_RELOAD)" -eq 1 ]; then
						echo history > $ACT_GO
					fi
					rm "$MUX_RELOAD"
				fi
				;;
			"credits")
				echo info > $ACT_GO
				echo "muxcredits" > /tmp/fg_proc
				nice --20 /opt/muos/extra/muxcredits
				;;
		esac
	fi
done

