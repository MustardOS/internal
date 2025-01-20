#!/bin/sh

case ":$LD_LIBRARY_PATH:" in
	*":/opt/muos/extra/lib:"*) ;;
	*) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

. /opt/muos/script/var/func.sh

if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
	RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"
	if [ -f "$RGBCONF_SCRIPT" ]; then
		"$RGBCONF_SCRIPT"
	else
		/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
	fi
fi

/opt/muos/device/current/input/combo/audio.sh I
/opt/muos/device/current/input/combo/bright.sh I

ACT_GO=/tmp/act_go
APP_GO=/tmp/app_go
ASS_GO=/tmp/ass_go
GOV_GO=/tmp/gov_go
GVR_GO=/tmp/gvr_go
IDX_GO=/tmp/idx_go
PIK_GO=/tmp/pik_go
ROM_GO=/tmp/rom_go
RES_GO=/tmp/res_go

EX_CARD=/tmp/explore_card
EX_NAME=/tmp/explore_name
EX_DIR=/tmp/explore_dir

CL_DIR=/tmp/collection_dir
CL_AMW=/tmp/add_mode_work

MUX_AUTH=/tmp/mux_auth

DEF_ACT=$(GET_VAR "global" "settings/general/startup")
printf '%s\n' "$DEF_ACT" >$ACT_GO
if [ "$DEF_ACT" = "explore" ]; then printf '%s\n' "explore_alt" >$ACT_GO; fi

echo "root" >$EX_CARD

if [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 1 ]; then
	LOG_INFO "$0" 0 "FRONTEND" "Changing to a random theme"
	/opt/muos/script/package/theme.sh install "?R"
fi

LAST_PLAY=$(cat "/opt/muos/config/lastplay.txt")

LOG_INFO "$0" 0 "FRONTEND" "Setting default CPU governor"
DEF_GOV=$(GET_VAR "device" "cpu/default")
printf '%s\n' "$DEF_GOV" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
if [ "$DEF_GOV" = ondemand ]; then
	GET_VAR "device" "cpu/sampling_rate_default" >"$(GET_VAR "device" "cpu/sampling_rate")"
	GET_VAR "device" "cpu/up_threshold_default" >"$(GET_VAR "device" "cpu/up_threshold")"
	GET_VAR "device" "cpu/sampling_down_factor_default" >"$(GET_VAR "device" "cpu/sampling_down_factor")"
	GET_VAR "device" "cpu/io_is_busy_default" >"$(GET_VAR "device" "cpu/io_is_busy")"
fi

LOG_INFO "$0" 0 "FRONTEND" "Checking for last or resume startup"
if [ "$(GET_VAR "global" "settings/general/startup")" = "last" ] || [ "$(GET_VAR "global" "settings/general/startup")" = "resume" ]; then
	if [ -n "$LAST_PLAY" ]; then
		LOG_INFO "$0" 0 "FRONTEND" "Checking for network and retrowait"
		if [ "$(GET_VAR "global" "network/enabled")" -eq 1 ] && [ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 1 ]; then
			NET_START="/tmp/net_start"
			OIP=0
			while :; do
				NW_MSG=$(printf "Waiting for network to connect... (%s)\n\nPress START to continue loading\nPress SELECT to go to main menu" "$OIP")
				/opt/muos/extra/muxstart 0 "$NW_MSG"
				OIP=$((OIP + 1))
				if [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Network connected"
					/opt/muos/extra/muxstart 0 "Network connected"

					PIP=0
					while ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; do
						PIP=$((PIP + 1))
						LOG_INFO "$0" 0 "FRONTEND" "Verifying connectivity..."
						/opt/muos/extra/muxstart 0 "Verifying connectivity... (%s)" "$PIP"
						sleep 1
					done

					LOG_SUCCESS "$0" 0 "FRONTEND" "Connectivity verified!"
					/opt/muos/extra/muxstart 0 "Connectivity verified! Booting content!"
					break
				fi
				if [ "$(cat "$NET_START")" = "ignore" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Ignoring network connection"
					/opt/muos/extra/muxstart 0 "Ignoring network connection... Booting content!"
					break
				fi
				if [ "$(cat "$NET_START")" = "menu" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Booting to main menu"
					/opt/muos/extra/muxstart 0 "Booting to main menu!"
					break
				fi
				sleep 1
			done
		fi
		if [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ] || [ "$(cat "$NET_START")" = "ignore" ] || [ "$(GET_VAR "global" "network/enabled")" -eq 0 ] || [ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 0 ]; then
			LOG_INFO "$0" 0 "FRONTEND" "Booting to last launched content"
			cat "$LAST_PLAY" >"$ROM_GO"

			CONTENT_GOV="$(basename "$LAST_PLAY" .cfg).gov"
			if [ -e "$CONTENT_GOV" ]; then
				printf "%s" "$(cat "$CONTENT_GOV")" >$GVR_GO
			else
				CONTENT_GOV="$(dirname "$LAST_PLAY")/core.gov"
				if [ -e "$CONTENT_GOV" ]; then
					printf "%s" "$(cat "$CONTENT_GOV")" >$GVR_GO
				else
					LOG_INFO "$0" 0 "FRONTEND" "No governor found for launched content"
				fi
			fi

			/opt/muos/script/mux/launch.sh last
		fi
	fi
	echo launcher >$ACT_GO
fi

LOG_INFO "$0" 0 "FRONTEND" "Starting frontend launcher"
cp /opt/muos/*.log "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/boot/." &

while :; do
	CHECK_BGM ignore

	# Reset DPAD<>ANALOGUE switch for H700 devices
	case "$(GET_VAR "device" "board/name")" in
		rg*) echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
		*) ;;
	esac

	# Content Association
	if [ -s "$ASS_GO" ]; then
		ROM_NAME=$(sed -n '1p' "$ASS_GO")
		ROM_DIR=$(sed -n '2p' "$ASS_GO")
		ROM_SYS=$(sed -n '3p' "$ASS_GO")

		ROM_FORCED=$(sed -n '4p' "$ASS_GO")
		rm "$ASS_GO"

		if [ "$ROM_FORCED" -eq 1 ]; then
			LOG_INFO "$0" 0 "FRONTEND" "Content Association Forced"
			echo "option" >$ACT_GO
		else
			echo "assign" >$ACT_GO
		fi
	fi

	# Content Governor
	if [ -s "$GOV_GO" ]; then
		ROM_NAME=$(sed -n '1p' "$GOV_GO")
		ROM_DIR=$(sed -n '2p' "$GOV_GO")
		ROM_SYS=$(sed -n '3p' "$GOV_GO")

		GOV_FORCED=$(sed -n '4p' "$GOV_GO")
		rm "$GOV_GO"

		if [ "$GOV_FORCED" -eq 1 ]; then
			LOG_INFO "$0" 0 "FRONTEND" "Content Governor Forced"
			echo "option" >$ACT_GO
		else
			echo "governor" >$ACT_GO
		fi
	fi

	# Content Loader
	if [ -s "$ROM_GO" ]; then
		/opt/muos/script/mux/launch.sh list
	fi

	# Application Loader
	if [ -s "$APP_GO" ]; then
		RUN_APP=$(cat "$APP_GO")
		case "$RUN_APP" in
			*"Archive Manager"* | *"Task Toolkit"*) ;;
			*) STOP_BGM ;;
		esac
		"$RUN_APP"
		rm "$APP_GO"
		CHECK_BGM ignore
		continue
	fi

	# Get Last ROM Index
	if [ "$(cat $ACT_GO)" = "explore" ] || [ "$(cat $ACT_GO)" = "collection" ] || [ "$(cat $ACT_GO)" = "history" ]; then
		LAST_INDEX_ROM=0
		if [ -s "$IDX_GO" ] && [ ! -s "$CL_AMW" ]; then
			LAST_INDEX_ROM=$(cat "$IDX_GO")
			rm "$IDX_GO"
		fi
	fi

	# Kill PortMaster GPTOKEYB just in case!
	killall -q gptokeyb.armhf gptokeyb.aarch64 &

	# muX Programs
	if [ -s "$ACT_GO" ]; then
		case "$(cat $ACT_GO)" in
			"launcher")
				touch /tmp/pdi_go
				echo launcher >$ACT_GO
				[ -s "$MUX_AUTH" ] && rm "$MUX_AUTH"
				SET_VAR "system" "foreground_process" "muxlaunch"
				nice --20 /opt/muos/extra/muxlaunch
				;;
			"option")
				echo explore >$ACT_GO
				SET_VAR "system" "foreground_process" "muxoption"
				nice --20 /opt/muos/extra/muxoption -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;
			"search")
				echo option >$ACT_GO
				SET_VAR "system" "foreground_process" "muxsearch"
				nice --20 /opt/muos/extra/muxsearch -d "$(cat $EX_DIR 2>/dev/null)"
				if [ -s "$RES_GO" ]; then
					basename "$(cat "$RES_GO")" >$EX_NAME
					dirname "$(cat "$RES_GO")" >$EX_DIR
					printf "%s" "$(sed 's|.*/\([^/]*\)/ROMS.*|\1|' "$RES_GO")" >$EX_CARD

					SET_VAR "system" "foreground_process" "muxplore"
					nice --20 /opt/muos/extra/muxplore -i 0 -m "$(cat $EX_CARD)"
				fi
				;;
			"assign")
				echo option >$ACT_GO
				SET_VAR "system" "foreground_process" "muxassign"
				nice --20 /opt/muos/extra/muxassign -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;
			"governor")
				echo option >$ACT_GO
				SET_VAR "system" "foreground_process" "muxgov"
				nice --20 /opt/muos/extra/muxgov -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;
			"app")
				echo launcher >$ACT_GO
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					SET_VAR "system" "foreground_process" "muxpass"
					nice --20 /opt/muos/extra/muxpass -t launch
					if [ "$?" = 1 ]; then
						SET_VAR "system" "foreground_process" "muxapp"
						nice --20 /opt/muos/extra/muxapp
					fi
				else
					SET_VAR "system" "foreground_process" "muxapp"
					nice --20 /opt/muos/extra/muxapp
				fi
				;;
			"config")
				echo launcher >$ACT_GO
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					if [ -e "$MUX_AUTH" ]; then
						SET_VAR "system" "foreground_process" "muxconfig"
						nice --20 /opt/muos/extra/muxconfig
					else
						SET_VAR "system" "foreground_process" "muxpass"
						nice --20 /opt/muos/extra/muxpass -t setting
						if [ "$?" = 1 ]; then
							SET_VAR "system" "foreground_process" "muxconfig"
							nice --20 /opt/muos/extra/muxconfig
							touch "$MUX_AUTH"
						fi
					fi
				else
					SET_VAR "system" "foreground_process" "muxconfig"
					nice --20 /opt/muos/extra/muxconfig
				fi
				;;
			"info")
				echo launcher >$ACT_GO
				SET_VAR "system" "foreground_process" "muxinfo"
				nice --20 /opt/muos/extra/muxinfo
				;;
			"hdmi")
				echo tweakgen >$ACT_GO
				SET_VAR "system" "foreground_process" "muxhdmi"
				nice --20 /opt/muos/extra/muxhdmi
				while [ ! -f "/tmp/hdmi_init_done" ]; do
                	sleep 0.25
                done
                rm -f "/tmp/hdmi_init_done"
				;;
			"power")
				echo tweakgen >$ACT_GO
				SET_VAR "system" "foreground_process" "muxpower"
				nice --20 /opt/muos/extra/muxpower
				;;
			"tweakgen")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtweakgen"
				nice --20 /opt/muos/extra/muxtweakgen
				;;
			"tweakadv")
				echo tweakgen >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtweakadv"
				nice --20 /opt/muos/extra/muxtweakadv
				;;
			"picker")
				echo custom >$ACT_GO
				SET_VAR "system" "foreground_process" "muxpicker"
				nice --20 /opt/muos/extra/muxpicker -m "$(cat $PIK_GO)"
				;;
			"custom")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxcustom"
				nice --20 /opt/muos/extra/muxcustom
				;;
			"visual")
				echo tweakgen >$ACT_GO
				SET_VAR "system" "foreground_process" "muxvisual"
				nice --20 /opt/muos/extra/muxvisual
				;;
			"storage")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxstorage"
				nice --20 /opt/muos/extra/muxstorage
				;;
			"net_profile")
				echo network >$ACT_GO
				SET_VAR "system" "foreground_process" "muxnetprofile"
				nice --20 /opt/muos/extra/muxnetprofile
				;;
			"net_scan")
				echo network >$ACT_GO
				SET_VAR "system" "foreground_process" "muxnetscan"
				nice --20 /opt/muos/extra/muxnetscan
				;;
			"network")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxnetwork"
				nice --20 /opt/muos/extra/muxnetwork
				;;
			"webserv")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxwebserv"
				nice --20 /opt/muos/extra/muxwebserv
				;;
			"rtc")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxrtc"
				nice --20 /opt/muos/extra/muxrtc
				;;
			"language")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxlanguage"
				nice --20 /opt/muos/extra/muxlanguage
				;;
			"timezone")
				echo rtc >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtimezone"
				nice --20 /opt/muos/extra/muxtimezone
				;;
			"tester")
				echo info >$ACT_GO
				SET_VAR "system" "foreground_process" "muxtester"
				nice --20 /opt/muos/extra/muxtester
				;;
			"device")
				echo config >$ACT_GO
				SET_VAR "system" "foreground_process" "muxdevice"
				nice --20 /opt/muos/extra/muxdevice
				;;
			"system")
				echo info >$ACT_GO
				SET_VAR "system" "foreground_process" "muxsysinfo"
				nice --20 /opt/muos/extra/muxsysinfo
				;;
			"explore")
				EXPLORE_DIR=$(cat $EX_DIR 2>/dev/null)
				echo launcher >$ACT_GO
				echo "$LAST_INDEX_SYS" >/tmp/lisys

				SET_VAR "system" "foreground_process" "muxassign"
				nice --20 /opt/muos/extra/muxassign -a 1 -c "$ROM_NAME" -d "$EXPLORE_DIR" -s none

				SET_VAR "system" "foreground_process" "muxgov"
				nice --20 /opt/muos/extra/muxgov -a 1 -c "$ROM_NAME" -d "$EXPLORE_DIR" -s none

				SET_VAR "system" "foreground_process" "muxplore"
				nice --20 /opt/muos/extra/muxplore -d "$EXPLORE_DIR" -i "$LAST_INDEX_ROM"
				;;
			"collection")
				if [ -s "$CL_AMW" ]; then
					ADD_MODE=1
					LAST_INDEX_ROM=0
				else
					ADD_MODE=0
				fi

				COLLECTION_DIR=$(cat $CL_DIR 2>/dev/null)
				echo launcher >$ACT_GO
				echo "$LAST_INDEX_SYS" >/tmp/lisys
				find "/run/muos/storage/info/collection" -maxdepth 2 -type f -size 0 -delete

				SET_VAR "system" "foreground_process" "muxcollect"
				nice --20 /opt/muos/extra/muxcollect -a "$ADD_MODE" -d "$COLLECTION_DIR" -i "$LAST_INDEX_ROM"
				;;
			"history")
				find "/run/muos/storage/info/history" -maxdepth 1 -type f -size 0 -delete

				echo launcher >$ACT_GO
				SET_VAR "system" "foreground_process" "muxhistory"
				nice --20 /opt/muos/extra/muxhistory -i "$LAST_INDEX_ROM"
				;;
			"credits")
				echo info >$ACT_GO
				SET_VAR "system" "foreground_process" "muxcredits"
				nice --20 /opt/muos/extra/muxcredits
				;;
			"reboot")
				/opt/muos/script/mux/quit.sh reboot frontend
				;;
			"shutdown")
				/opt/muos/script/mux/quit.sh poweroff frontend
				;;
		esac
	fi
done
