#!/bin/sh
# shellcheck disable=1090,2002

. /opt/muos/script/system/parse.sh
CONFIG=/opt/muos/config/config.txt

ACT_GO=/tmp/act_go
ASS_GO=/tmp/ass_go
ROM_GO=/tmp/rom_go

EX_CARD=/tmp/explore_card

SND_PIPE=/tmp/muplay_pipe

MUX_RELOAD=/tmp/mux_reload
MUX_AUTH=/tmp/mux_auth

STARTUP=$(parse_ini "$CONFIG" "settings.general" "startup")
echo "$STARTUP" > $ACT_GO
echo "root" > $EX_CARD

LOGGER() {
VERBOSE=$(parse_ini "$CONFIG" "settings.advanced" "verbose")
if [ "$VERBOSE" -eq 1 ]; then
	_TITLE=$1
	_MESSAGE=$2
	_FORM=$(cat <<EOF
$_TITLE

$_MESSAGE
EOF
	)
	/opt/muos/extra/muxstart "$_FORM" && sleep 0.5
fi
}

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

LAST_PLAY="/opt/muos/config/lastplay.txt"
STARTUP=$(parse_ini "$CONFIG" "settings.general" "startup")
if [ "$STARTUP" = last ]; then
	if [ -s "$LAST_PLAY" ]; then
		cat "$LAST_PLAY" > "$ROM_GO"
		/opt/muos/script/mux/launch.sh
	else
		echo launcher > $ACT_GO
	fi
fi

while true; do
	# Background Music
	BGM_SOUND=$(parse_ini "$CONFIG" "settings.general" "bgm")
	if [ "$BGM_SOUND" -eq 1 ]; then
		if ! pgrep -f "playbgm.sh" > /dev/null; then
			/opt/muos/script/mux/playbgm.sh
		fi
	else
		KILL_BGM
	fi

	# Navigation Sounds
	NAV_SOUND=$(parse_ini "$CONFIG" "settings.general" "sound")
	if [ "$NAV_SOUND" -eq 1 ]; then
		if ! pgrep -f "muplay" > /dev/null; then
			mkfifo "$SND_PIPE"
			/opt/muos/bin/muplay "$SND_PIPE" &
		fi
	else
		KILL_SND
	fi

	# Core Association
	if [ -s "$ASS_GO" ]; then
		ROM_DIR=$(cat "$ASS_GO" | sed -n '1p')
		ROM_SYS=$(cat "$ASS_GO" | sed -n '2p')

		rm "$ASS_GO"
		echo "assign" > $ACT_GO
	fi

	# Content Loader
	/opt/muos/script/mux/launch.sh

	# Get Last ROM Index
	if [ "$(cat $ACT_GO)" = explore ] || [ "$(cat $ACT_GO)" = favourite ] || [ "$(cat $ACT_GO)" = history ]; then
		if [ -s "/tmp/mux_lastindex_rom" ]; then
			LAST_INDEX_ROM=$(cat "/tmp/mux_lastindex_rom")
			rm "/tmp/mux_lastindex_rom"
		else
			LAST_INDEX_ROM=0
		fi
	fi

	# Kill PortMaster GPTOKEYB just in case!
	killall -q gptokeyb.armhf
	killall -q gptokeyb.aarch64

	if [ "$(cat /opt/muos/config/device.txt)" = "RG28XX" ]; then
		export SDL_HQ_SCALER=1
	fi

	# muX Programs
	if [ -s "$ACT_GO" ]; then
		case "$(cat $ACT_GO)" in
			"launcher")
				echo launcher > $ACT_GO
				rm "$MUX_AUTH"
				nice --20 /opt/muos/extra/muxlaunch
				;;
			"assign")
				echo explore > $ACT_GO
				echo "$LAST_INDEX_SYS" > /tmp/lisys
				nice --20 /opt/muos/extra/muxassign -a 0 -d "$ROM_DIR" -s "$ROM_SYS"
				;;
			"explore")
				MODULE=$(cat "$EX_CARD" | sed -n '1p')
				echo launcher > $ACT_GO
				echo "$LAST_INDEX_SYS" > /tmp/lisys
				nice --20 /opt/muos/extra/muxassign -a 1 -d "$(cat /tmp/explore_dir)" -s none
				nice --20 /opt/muos/extra/muxplore -i "$LAST_INDEX_ROM" -m "$MODULE"
				;;
			"apps")
				echo launcher > $ACT_GO
				LOCK=$(parse_ini "$CONFIG" "settings.advanced" "lock")
				if [ "$LOCK" -eq 1 ]; then
				        nice --20 /opt/muos/extra/muxpass -t launch
					if [ "$?" = 1 ]; then
						nice --20 /opt/muos/extra/muxapps
					fi
				else
					nice --20 /opt/muos/extra/muxapps
				fi
				;;
			"config")
				echo launcher > $ACT_GO
				LOCK=$(parse_ini "$CONFIG" "settings.advanced" "lock")
				if [ "$LOCK" -eq 1 ]; then
					if [ -e "$MUX_AUTH" ]; then
						nice --20 /opt/muos/extra/muxconfig
					else
						nice --20 /opt/muos/extra/muxpass -t setting
						if [ "$?" = 1 ]; then
							nice --20 /opt/muos/extra/muxconfig
							touch "$MUX_AUTH"
						fi
					fi
				else
					nice --20 /opt/muos/extra/muxconfig
				fi
				;;
			"info")
				echo launcher > $ACT_GO
				nice --20 /opt/muos/extra/muxinfo
				;;
			"tweakgen")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxtweakgen
				;;
			"tweakadv")
				echo tweakgen > $ACT_GO
				nice --20 /opt/muos/extra/muxtweakadv
				;;
			"archive")
				echo apps > $ACT_GO
				nice --20 /opt/muos/extra/muxarchive
				;;
			"theme")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxtheme
				;;
			"visual")
				echo tweakgen > $ACT_GO
				nice --20 /opt/muos/extra/muxvisual
				;;
			"net_scan")
				echo network > $ACT_GO
				nice --20 /opt/muos/extra/muxnetscan
				;;
			"network")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxnetwork
				;;
			"webserv")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxwebserv
				;;
			"rtc")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxrtc
				;;
			"timezone")
				echo rtc > $ACT_GO
				nice --20 /opt/muos/extra/muxtimezone
				;;
			"import")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muximport
				;;
			"tracker")
				echo info > $ACT_GO
				nice --20 /opt/muos/extra/muxtracker -m "$MSG_SUPPRESS"
				if [ -s "$MUX_RELOAD" ]; then
					if [ "$(cat $MUX_RELOAD)" -eq 1 ]; then
						echo tracker > $ACT_GO
					fi
					rm "$MUX_RELOAD"
				fi
				;;
			"sdcard")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxsdtool
				;;
			"tester")
				echo info > $ACT_GO
				nice --20 /opt/muos/extra/muxtester
				;;
			"bios")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxbioscheck
				;;
			"backup")
				echo apps > $ACT_GO
				nice --20 /opt/muos/extra/muxbackup
				;;
			"reset")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxreset
				;;
			"device")
				echo config > $ACT_GO
				nice --20 /opt/muos/extra/muxdevice
				;;
			"system")
				echo info > $ACT_GO
				nice --20 /opt/muos/extra/muxsysinfo
				;;
			"profile")
				echo launcher > $ACT_GO
				nice --20 /opt/muos/extra/muxprofile
				;;
			"favourite")
				find /mnt/mmc/MUOS/info/favourite -maxdepth 1 -type f -size 0 -delete
				echo launcher > $ACT_GO
				nice --20 /opt/muos/extra/muxplore -i "$LAST_INDEX_ROM" -m favourite
				if [ -s "$MUX_RELOAD" ]; then
					if [ "$(cat $MUX_RELOAD)" -eq 1 ]; then
						echo favourite > $ACT_GO
					fi
					rm "$MUX_RELOAD"
				fi
				;;
			"history")
				find /mnt/mmc/MUOS/info/history -maxdepth 1 -type f -size 0 -delete
				echo launcher > $ACT_GO
				nice --20 /opt/muos/extra/muxplore -i 0 -m history
				if [ -s "$MUX_RELOAD" ]; then
					if [ "$(cat $MUX_RELOAD)" -eq 1 ]; then
						echo history > $ACT_GO
					fi
					rm "$MUX_RELOAD"
				fi
				;;
			"portmaster")
				KILL_BGM
				KILL_SND
				echo apps > $ACT_GO
				export HOME=/root
				nice --20 /mnt/mmc/MUOS/PortMaster/PortMaster.sh
				;;
			"retro")
				KILL_BGM
				KILL_SND
				echo apps > $ACT_GO
				export HOME=/root
				nice --20 retroarch -c "/mnt/mmc/MUOS/retroarch/retroarch.cfg"
				;;
			"dingux")
				KILL_BGM
				KILL_SND
				echo apps > $ACT_GO
				export HOME=/root
				nice --20 /opt/muos/app/dingux.sh
				;;
			"gmu")
				KILL_BGM
				KILL_SND
				echo apps > $ACT_GO
				export HOME=/root
				nice --20 /opt/muos/app/gmu.sh
				;;
			"shuffle")
				echo launcher > $ACT_GO
				nice --20 /opt/muos/extra/muxshuffle
				;;
			"credits")
				echo info > $ACT_GO
				nice --20 /opt/muos/extra/muxcredits
				;;
		esac
	fi
done

