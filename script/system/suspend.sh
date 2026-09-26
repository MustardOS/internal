#!/bin/sh

. /opt/muos/script/var/func.sh

# Lonely, oh so lonely...
RECENT_WAKE="$MUOS_RUN_DIR/recent_wake"
LED_STATE="$MUOS_RUN_DIR/work_led_state"
MUXRETRO_SAVE_READY="$MUOS_RUN_DIR/muxretro_save_ready"
MUXRETRO_SUSPEND_SIGNAL="USR1"
MUXRETRO_RESUME_SIGNAL="USR2"

G350_SUSPEND_DEBUG="/opt/muos/config/g350-suspend-debug"

RECENT_WAKE_GRACE="${RECENT_WAKE_GRACE:-6}"
RECENT_WAKE_STALE="${RECENT_WAKE_STALE:-60}"
MUXRETRO_SAVE_WAIT_STEPS="${MUXRETRO_SAVE_WAIT_STEPS:-100}"

BOARD_NAME=$(GET_VAR "device" "board/name")
HAS_NETWORK=$(GET_VAR "device" "board/network")
NET_NAME=$(GET_VAR "device" "network/name")
CPU_GOV_PATH="$(GET_VAR "device" "cpu/governor")"
LED_NORMAL="$(GET_VAR "device" "led/normal")"
LED_RGB="$(GET_VAR "device" "led/rgb")"
RUMBLE_DEVICE="$(GET_VAR "device" "board/rumble")"
RTC_WAKE_PATH="$(GET_VAR "device" "board/rtc_wake")"
MAX_BRIGHT=$(GET_VAR "device" "screen/bright")
CHARGER_PATH="$(GET_VAR "device" "battery/charger")"

RGB_ENABLE=$(GET_VAR "config" "settings/general/rgb")
RUMBLE_SETTING="$(GET_VAR "config" "settings/advanced/rumble")"
SUSPEND_STATE="$(GET_VAR "config" "danger/state")"
DEFAULT_BRIGHTNESS="$(GET_VAR "config" "settings/general/brightness")"
SHUTDOWN_TIME_SETTING="$(GET_VAR "config" "settings/power/shutdown")"
CONNECT_ON_WAKE=$(GET_VAR "config" "settings/network/wake")
USE_ACTIVITY="$(GET_VAR "config" "settings/advanced/activity")"
USB_FUNCTION="$(GET_VAR "config" "settings/advanced/usb_function")"

# We'll keep the suspend state for the G350 at freeze for now, not that it even works!
if [ "$BOARD_NAME" = rk-g350-v ] && [ "$SUSPEND_STATE" = mem ]; then
	SUSPEND_STATE=freeze
fi

CHARGER_CONNECTED() {
	[ -n "$CHARGER_PATH" ] && [ -r "$CHARGER_PATH" ] || return 1
	CHARGER_STATE=0
	IFS= read -r CHARGER_STATE <"$CHARGER_PATH" 2>/dev/null || return 1
	[ "$CHARGER_STATE" -eq 1 ] 2>/dev/null
}

G350_PREPARE_WAKE() {
	[ "$BOARD_NAME" = rk-g350-v ] || return 0
	[ "${G350_PM_TEST_ACTIVE:-0}" -eq 1 ] || [ -r "$G350_SUSPEND_DEBUG" ] || return 0
	G350_PMIC_PATH=/sys/devices/platform/ff180000.i2c/i2c-0/0-0020

	G350_CONSOLE_SUSPEND_OLD=
	G350_PRINTK_OLD=
	[ -r /sys/module/printk/parameters/console_suspend ] && \
		IFS= read -r G350_CONSOLE_SUSPEND_OLD </sys/module/printk/parameters/console_suspend
	[ -r /proc/sys/kernel/printk ] && IFS= read -r G350_PRINTK_OLD </proc/sys/kernel/printk

	# The G350 ships with an old crappy 4.4 kernel. Serialising the device PM
	# avoids dependency races during suspend or resume, while the extra PM output
	# is captured by the device tree console if the kernel never returns properly...
	[ -w /sys/power/pm_async ] && printf '%s' 0 >/sys/power/pm_async
	[ -w /sys/power/pm_print_times ] && printf '%s' 1 >/sys/power/pm_print_times
	[ -w /sys/module/printk/parameters/console_suspend ] && \
		printf '%s' N >/sys/module/printk/parameters/console_suspend
	[ -w /proc/sys/kernel/printk ] && printf '%s\n' '8 4 1 7' >/proc/sys/kernel/printk

	for G350_WAKE_CONTROL in \
		"$G350_PMIC_PATH"/power/wakeup \
		"$G350_PMIC_PATH"/*/power/wakeup \
		"$G350_PMIC_PATH"/input/*/device/power/wakeup \
		/sys/devices/platform/ff180000.i2c/power/wakeup \
		/sys/devices/platform/ff040000.gpio/power/wakeup; do
		[ -w "$G350_WAKE_CONTROL" ] && printf '%s' enabled >"$G350_WAKE_CONTROL"
	done
}

G350_RESTORE_PM_DEBUG() {
	[ "$BOARD_NAME" = rk-g350-v ] || return 0

	[ -n "$G350_CONSOLE_SUSPEND_OLD" ] && \
		[ -w /sys/module/printk/parameters/console_suspend ] && \
		printf '%s' "$G350_CONSOLE_SUSPEND_OLD" >/sys/module/printk/parameters/console_suspend
	[ -n "$G350_PRINTK_OLD" ] && [ -w /proc/sys/kernel/printk ] && \
		printf '%s\n' "$G350_PRINTK_OLD" >/proc/sys/kernel/printk
}

G350_PREPARE_PM_TEST() {
	G350_PM_TEST_ACTIVE=0
	G350_INITCALL_DEBUG_OLD=
	[ "$BOARD_NAME" = rk-g350-v ] || return 0

	G350_PM_TEST_REQUEST=/opt/muos/config/g350-pm-test
	G350_PM_TEST_RUNNING=/opt/muos/config/g350-pm-test.running

	[ -r "$G350_PM_TEST_REQUEST" ] || return 0
	[ -w /sys/power/pm_test ] || {
		mv "$G350_PM_TEST_REQUEST" /opt/muos/config/g350-pm-test.unsupported
		return 1
	}

	G350_PM_TEST_LEVEL=
	IFS= read -r G350_PM_TEST_LEVEL <"$G350_PM_TEST_REQUEST" || return 1
	case "$G350_PM_TEST_LEVEL" in
		freezer | devices | platform | processors | core) ;;
		*)
			mv "$G350_PM_TEST_REQUEST" /opt/muos/config/g350-pm-test.invalid
			return 1
			;;
	esac

	mv "$G350_PM_TEST_REQUEST" "$G350_PM_TEST_RUNNING"
	printf '%s' "$G350_PM_TEST_LEVEL" >/sys/power/pm_test

	G350_INITCALL_DEBUG_PATH=/sys/module/kernel/parameters/initcall_debug

	if [ -r "$G350_INITCALL_DEBUG_PATH" ]; then
		IFS= read -r G350_INITCALL_DEBUG_OLD <"$G350_INITCALL_DEBUG_PATH"
	fi

	[ -w "$G350_INITCALL_DEBUG_PATH" ] && printf '%s' Y >"$G350_INITCALL_DEBUG_PATH"

	SUSPEND_STATE=mem
	G350_PM_TEST_ACTIVE=1

	sync
}

G350_COMPLETE_PM_TEST() {
	[ "$G350_PM_TEST_ACTIVE" -eq 1 ] || return 0

	printf '%s' none >/sys/power/pm_test
	[ -n "$G350_INITCALL_DEBUG_OLD" ] && [ -w "$G350_INITCALL_DEBUG_PATH" ] && printf '%s' "$G350_INITCALL_DEBUG_OLD" >"$G350_INITCALL_DEBUG_PATH"

	mv "$G350_PM_TEST_RUNNING" "/opt/muos/config/g350-pm-test.$1"
}

RUN_SUSPEND_BACKEND() {
	SUSPEND_HELPER=/opt/muos/frontend/mususpend
	if [ ! -x "$SUSPEND_HELPER" ]; then
		G350_LOG_SUSPEND suspend-helper-unavailable
		return 1
	fi

	SHUTDOWN_EPOCH=${WAKE_EPOCH:-0}
	case "$SHUTDOWN_EPOCH" in
		'' | *[!0-9]*) SHUTDOWN_EPOCH=0 ;;
	esac

	REMAINING=
	if [ "$SHUTDOWN_EPOCH" -gt 0 ]; then
		CURRENT_EPOCH=$(cat "$RTC_WAKE_PATH/since_epoch" 2>/dev/null || printf '%s' 0)
		REMAINING=$((SHUTDOWN_EPOCH - CURRENT_EPOCH))
		[ "$REMAINING" -lt 0 ] && REMAINING=0
	fi

	POWER_DEVICE=
	case "$BOARD_NAME" in
		rk-g350-v) POWER_DEVICE=rk8xx_pwrkey ;;
		rg-vita-pro) POWER_DEVICE="rk805 pwrkey" ;;
	esac

	if [ -n "$POWER_DEVICE" ]; then
		G350_LOG_SUSPEND userspace-wait

		if [ -n "$REMAINING" ]; then
			"$SUSPEND_HELPER" --state userspace --power-device "$POWER_DEVICE" --optimise \
				--quiesce muxfrontend --quiesce muxretro --quiesce retroarch --timeout "$REMAINING"
		else
			"$SUSPEND_HELPER" --state userspace --power-device "$POWER_DEVICE" --optimise \
				--quiesce muxfrontend --quiesce muxretro --quiesce retroarch
		fi
	else
		if [ -n "$REMAINING" ]; then
			"$SUSPEND_HELPER" --state "$SUSPEND_STATE" --timeout "$REMAINING"
		else
			"$SUSPEND_HELPER" --state "$SUSPEND_STATE"
		fi
	fi
	SUSPEND_RESULT=$?

	case "$SUSPEND_RESULT" in
		0) G350_LOG_SUSPEND power-key-wake ;;
		2) G350_LOG_SUSPEND shutdown-deadline ;;
		*)
			G350_LOG_SUSPEND suspend-backend-failed
			return 1
			;;
	esac

	return 0
}

# We'll keep a log of this until we figure out why the fuck it isn't waking up properly.
G350_LOG_SUSPEND() {
	[ "$BOARD_NAME" = rk-g350-v ] || return 0
	[ -r "$G350_SUSPEND_DEBUG" ] || [ "${G350_PM_TEST_ACTIVE:-0}" -eq 1 ] || return 0
	G350_PMIC_PATH=/sys/devices/platform/ff180000.i2c/i2c-0/0-0020

	{
		printf '\nphase=%s uptime=' "$1"
		cat /proc/uptime

		printf 'state=%s supported=' "$SUSPEND_STATE"
		cat /sys/power/state

		if [ -r /sys/power/pm_test ]; then
			printf 'pm_test='
			cat /sys/power/pm_test
		fi

		for G350_WAKE_CONTROL in \
			"$G350_PMIC_PATH"/power/wakeup \
			"$G350_PMIC_PATH"/*/power/wakeup \
			"$G350_PMIC_PATH"/input/*/device/power/wakeup \
			/sys/devices/platform/ff180000.i2c/power/wakeup \
			/sys/devices/platform/ff040000.gpio/power/wakeup; do
			[ -r "$G350_WAKE_CONTROL" ] || continue
			printf 'wakeup[%s]=' "$G350_WAKE_CONTROL"
			cat "$G350_WAKE_CONTROL"
		done

		grep -E 'rk8xx|rk808|rk817|ff180000|gpio0' /proc/interrupts 2>/dev/null || :
		grep -E 'rk8xx|rk808|rk817|ff180000|gpio0' /sys/kernel/debug/wakeup_sources 2>/dev/null || :
	} >>/opt/muos/config/g350-suspend.log 2>&1

	sync
}

UPTIME_SEC() {
	U=$(cut -d ' ' -f 1 /proc/uptime 2>/dev/null || echo 0)
	U=${U%%.*}
	[ -n "$U" ] || U=0
	printf '%s\n' "$U"
}

RECENT_WAKE_SET() {
	[ -f "$RECENT_WAKE" ] || return 1

	T=0
	read -r T <"$RECENT_WAKE" 2>/dev/null || T=0
	T=${T%%.*}
	[ -n "$T" ] || T=0

	NOW="$(UPTIME_SEC)"
	AGE=$((NOW - T))

	# If clock went backwards(?!) or file is stale fuck it off
	if [ "$AGE" -lt 0 ] || [ "$AGE" -ge "$RECENT_WAKE_STALE" ]; then
		rm -f "$RECENT_WAKE" 2>/dev/null || :
		return 1
	fi

	return 0
}

RECENT_WAKE_MARK() {
	UPTIME_SEC >"$RECENT_WAKE"
}

RECENT_WAKE_CLEAR_LATER() {
	# Use nohup so it survives parent exit reliably!
	nohup sh -c "sleep \"$RECENT_WAKE_GRACE\"; rm -f \"$RECENT_WAKE\"" >/dev/null 2>&1 &
}

ACTIVITY_TRACKER() {
	[ "${USE_ACTIVITY:-0}" -eq 1 ] || return 0

	TRACK_CURRENT="$MUOS_STORE_DIR/info/track/.current_session"
	[ -r "$TRACK_CURRENT" ] || return 0

	{
		read -r T_NAME
		read -r T_CORE
		read -r T_ROM
	} <"$TRACK_CURRENT"

	[ -n "$T_ROM" ] || return 0

	/opt/muos/script/mux/track.sh "$T_NAME" "$T_CORE" "$T_ROM" "$1"
}

CHECK_RA_AND_SAVE() {
	# This is the safest bet to get RetroArch to save state automatically
	# if the user has configured their settings to do so...

	[ "$(GET_VAR "system" "foreground_process")" = "retroarch" ] && /usr/bin/retroarch --command "$1"

	# If you're reading this and thinking "WhAt AbOuT pOrTmAsTeR gAmEs?"
	# My answer is, you find out how to restore save game content and let us know!
}

CHECK_MUXRETRO_AND_SAVE() {
	# muxretro hosts libretro cores in process, it listens for:
	# SIGUSR1 (save state + flush sram + pause + acknowledgement)
	# SIGUSR2 (resume)

	MUXRETRO_PID="$(pidof muxretro)"
	MUXRETRO_PID=${MUXRETRO_PID%% *}
	[ -n "$MUXRETRO_PID" ] || return 0

	if [ "$1" != "$MUXRETRO_SUSPEND_SIGNAL" ]; then
		kill -"$1" "$MUXRETRO_PID" 2>/dev/null || :
		return 0
	fi

	rm -f "$MUXRETRO_SAVE_READY" 2>/dev/null || :
	kill -"$MUXRETRO_SUSPEND_SIGNAL" "$MUXRETRO_PID" 2>/dev/null || return 0

	WAIT_STEP=0
	while [ "$WAIT_STEP" -lt "$MUXRETRO_SAVE_WAIT_STEPS" ]; do
		MUXRETRO_READY_PID=""
		[ -r "$MUXRETRO_SAVE_READY" ] && read -r MUXRETRO_READY_PID <"$MUXRETRO_SAVE_READY"
		if [ "$MUXRETRO_READY_PID" = "$MUXRETRO_PID" ]; then
			rm -f "$MUXRETRO_SAVE_READY" 2>/dev/null || :
			return 0
		fi
		kill -0 "$MUXRETRO_PID" 2>/dev/null || break
		sleep 0.05
		WAIT_STEP=$((WAIT_STEP + 1))
	done

	rm -f "$MUXRETRO_SAVE_READY" 2>/dev/null || :
	LOG_WARN "$0" 0 "SUSPEND" "Pickles save acknowledgement timed out; continuing suspend"
}

QUIET_WAKE_LIST="$MUOS_RUN_DIR/quiet_wake"
SPEAKER_AMP_SWITCH="HpSpeaker Switch"
WAKE_SOURCE_SNAPSHOT="$MUOS_RUN_DIR/wake_sources"
WAKE_IRQ_SNAPSHOT="$MUOS_RUN_DIR/wake_irqs"
WAKE_TRACE="$MUOS_LOG_DIR/wake.trace"
WAKE_IRQ_PATTERN="axp|pek|vbus|battery|rtc|alarm|wake|wlan|bt_|nmi|key"

# Can't sleep, clowns will eat me!
QUIET_WAKE_SOURCES() {
	: >"$QUIET_WAKE_LIST"

	{
		find /sys/devices/platform -maxdepth 4 \( -path "*btlpm*/power/wakeup" -o -path "*wlan*/power/wakeup" \) 2>/dev/null
		for BATTERY_WAKE in /sys/class/power_supply/*battery*/power/wakeup; do
			[ -e "$BATTERY_WAKE" ] && printf '%s\n' "$BATTERY_WAKE"
		done
	} |
		while IFS= read -r WAKE_CONTROL; do
			WAKE_VALUE=
			read -r WAKE_VALUE <"$WAKE_CONTROL" 2>/dev/null
			[ "$WAKE_VALUE" = enabled ] || continue

			printf '%s' disabled >"$WAKE_CONTROL" 2>/dev/null && printf '%s\n' "$WAKE_CONTROL" >>"$QUIET_WAKE_LIST"
		done
}

RESTORE_WAKE_SOURCES() {
	[ -r "$QUIET_WAKE_LIST" ] || return 0

	while IFS= read -r WAKE_CONTROL; do
		[ -w "$WAKE_CONTROL" ] && printf '%s' enabled >"$WAKE_CONTROL"
	done <"$QUIET_WAKE_LIST"

	rm -f "$QUIET_WAKE_LIST"
}

SNAPSHOT_WAKE_SOURCES() {
	awk 'NR > 1 { print $1, $4 }' /sys/kernel/debug/wakeup_sources >"$WAKE_SOURCE_SNAPSHOT" 2>/dev/null
	IRQ_COUNTS >"$WAKE_IRQ_SNAPSHOT"
}

IRQ_COUNTS() {
	awk -v pattern="$WAKE_IRQ_PATTERN" '
		NR == 1 { cpus = NF; next }
		{
			total = 0
			for (i = 2; i <= cpus + 1; i++) total += $i
			name = $NF
			if (tolower(name) ~ pattern) print $1, name, total
		}
	' /proc/interrupts 2>/dev/null
}

REPORT_WAKE_SOURCE() {
	WAKE_IRQ=
	read -r WAKE_IRQ </sys/power/pm_wakeup_irq 2>/dev/null

	WAKE_IRQ_NAME=
	if [ -n "$WAKE_IRQ" ]; then
		WAKE_IRQ_NAME=$(awk -v irq="$WAKE_IRQ:" '$1 == irq { print $NF; exit }' /proc/interrupts 2>/dev/null)
	fi

	WOKEN_BY=
	if [ -r "$WAKE_SOURCE_SNAPSHOT" ]; then
		WOKEN_BY=$(awk 'NR == FNR { seen[$1] = $2; next } FNR > 1 && $4 > seen[$1] + 0 { printf "%s ", $1 }' \
			"$WAKE_SOURCE_SNAPSHOT" /sys/kernel/debug/wakeup_sources 2>/dev/null)
		rm -f "$WAKE_SOURCE_SNAPSHOT"
	fi

	FIRED_IRQS=
	if [ -r "$WAKE_IRQ_SNAPSHOT" ]; then
		FIRED_IRQS=$(IRQ_COUNTS | awk 'NR == FNR { seen[$1] = $3; next } $3 > seen[$1] + 0 { printf "%s ", $2 }' \
			"$WAKE_IRQ_SNAPSHOT" - 2>/dev/null)
		rm -f "$WAKE_IRQ_SNAPSHOT"
	fi

	WAKE_LINE=$(printf "Woke from sleep: %s(irq %s %s) fired: %s" "${WOKEN_BY:-no counted source }" \
		"${WAKE_IRQ:-unknown}" "${WAKE_IRQ_NAME:-unnamed}" "${FIRED_IRQS:-none}")
	LOG_INFO "$0" 0 "SUSPEND" "$WAKE_LINE"

	# Always kept as a spontaneous wake is rare on most devices... but good for logging!
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$WAKE_LINE" >>"$WAKE_TRACE" 2>/dev/null
	if [ "$(wc -l <"$WAKE_TRACE" 2>/dev/null)" -gt 50 ] 2>/dev/null; then
		tail -n 50 "$WAKE_TRACE" >"$WAKE_TRACE.tmp" && mv -f "$WAKE_TRACE.tmp" "$WAKE_TRACE"
	fi
}

SLEEP() {
	RECENT_WAKE_MARK

	LED_CONTROL_CHANGE off
	ACTIVITY_TRACKER suspend

	CHECK_MUXRETRO_AND_SAVE "$MUXRETRO_SUSPEND_SIGNAL"
	CHECK_RA_AND_SAVE "SAVE_STATE"
	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	DISPLAY_WRITE disp0 setbl 0
	amixer set "Master" mute >/dev/null 2>&1

	# Stop the pop!
	SPEAKER_AMP_STATE=
	if amixer -c 0 cget name="$SPEAKER_AMP_SWITCH" >/dev/null 2>&1; then
		SPEAKER_AMP_STATE=$(amixer -c 0 cget name="$SPEAKER_AMP_SWITCH" | sed -n 's/.*: values=//p')
		amixer -q -c 0 cset name="$SPEAKER_AMP_SWITCH" off >/dev/null 2>&1
	fi

	STOP_SSHD_GRACEFUL
	SAVE_CPU_GOV "$CPU_GOV_PATH"

	if [ "$RGB_ENABLE" -eq 1 ] && [ "$LED_RGB" -eq 1 ]; then
		LED_CONTROL_CHANGE off
	fi

	case "$BOARD_NAME" in
		rg*) echo "0" >"$LED_NORMAL" ;;
	esac

	case "$RUMBLE_SETTING" in
		3 | 5 | 6) RUMBLE "$RUMBLE_DEVICE" 0.3 ;;
	esac

	if [ "$HAS_NETWORK" -eq 1 ]; then
		/opt/muos/script/init/async/S02network.sh stop
	fi

	if [ "$HAS_NETWORK" -eq 1 ] && [ "$NET_NAME" = "8821cs" ]; then
		/opt/muos/script/init/S75bluetooth.sh stop
	fi

	/opt/muos/script/device/module.sh unload

	# G350 this, G350 that... sigh!
	if ! G350_PREPARE_PM_TEST; then
		G350_LOG_SUSPEND pm-test-unavailable
		return 0
	fi

	G350_PREPARE_WAKE
	G350_LOG_SUSPEND entering

	QUIET_WAKE_SOURCES
	SNAPSHOT_WAKE_SOURCES

	if [ "$G350_PM_TEST_ACTIVE" -eq 1 ]; then
		G350_LOG_SUSPEND pm-test-dispatch
		echo "$SUSPEND_STATE" >"/sys/power/state"
		G350_LOG_SUSPEND returned
		G350_COMPLETE_PM_TEST passed
	elif RUN_SUSPEND_BACKEND; then
		G350_LOG_SUSPEND returned
	else
		G350_LOG_SUSPEND backend-error
	fi

	REPORT_WAKE_SOURCE
	RESTORE_WAKE_SOURCES

	G350_RESTORE_PM_DEBUG

	sleep 0.5
}

RESUME() {
	# Start module loads in the background. The LED, USB, CPU governor,
	# and brightness restore do not depend on it.  Network reconnect does
	# (the module needs to be loaded first), so we'll wait before that.
	/opt/muos/script/device/module.sh load &
	MODULE_PID=$!

	LED_CONTROL_CHANGE restore

	[ "$USB_FUNCTION" -ne 0 ] && /opt/muos/script/system/usb_gadget.sh resume

	# Some stupid TrimUI GPU shenanigans
	case "$BOARD_NAME" in
		rg*) cat "$LED_STATE" >"$LED_NORMAL" ;;
		mgx* | tui*)
			setalpha 0
			(
				ALPHA_TRY=0
				while [ "$ALPHA_TRY" -lt 20 ]; do
					sleep 0.2
					setalpha 0
					ALPHA_TRY=$((ALPHA_TRY + 1))
				done
			) &
			;;
	esac

	RESTORE_CPU_GOV "$CPU_GOV_PATH"
	SYNC_GPU_FREQUENCY "$(cat "$CPU_GOV_PATH" 2>/dev/null)"
	SYNC_CPU_IDLE "$(cat "$CPU_GOV_PATH" 2>/dev/null)"
	SYNC_DMC_FREQUENCY "$(cat "$CPU_GOV_PATH" 2>/dev/null)"

	# Network module must be loaded before attempting reconnect
	wait "$MODULE_PID"

	if [ "$HAS_NETWORK" -eq 1 ] && [ "$NET_NAME" = "8821cs" ]; then
		/opt/muos/script/init/S75bluetooth.sh start &
	fi

	if [ "$HAS_NETWORK" -eq 1 ] && [ "$CONNECT_ON_WAKE" -eq 1 ]; then
		/opt/muos/script/init/async/S02network.sh start &
	fi

	ACTIVITY_TRACKER resume &

	# We're going to wait for the predefined grace period to stop sleep suspend from triggering again
	RECENT_WAKE_CLEAR_LATER

	# Restart hotkey just in case something explodes
	HOTKEY restart &

	CHECK_MUXRETRO_AND_SAVE "$MUXRETRO_RESUME_SIGNAL"
	CHECK_RA_AND_SAVE "MENU_TOGGLE"

	# Settle the codec on silence before the amplifier comes back on, the same as the boot fella
	if [ -n "$SPEAKER_AMP_STATE" ]; then
		/opt/muos/script/init/S80pipewire.sh prime >/dev/null 2>&1 ||
			LOG_WARN "$0" 0 "SUSPEND" "Audio output priming did not complete"
		amixer -q -c 0 cset name="$SPEAKER_AMP_SWITCH" "$SPEAKER_AMP_STATE" >/dev/null 2>&1
	fi

	amixer set "Master" unmute >/dev/null 2>&1

	E_BRIGHT="$DEFAULT_BRIGHTNESS"

	# Some display panels don't like to resume on lower backlights due
	# to potential voltage lines or some shit... so let's resume on
	# a bit more brightness unfortunately!
	[ "$E_BRIGHT" -le 8 ] && E_BRIGHT=16

	# We're going to do this twice because of how our brightness script
	# works with existing integer values.  It's a precise system!
	_UPTIME=$(cut -d. -f1 /proc/uptime)

	B=0
	while [ $B -lt 2 ]; do
		if [ $((_UPTIME % 2)) -eq 0 ]; then
			E_BRIGHT=$((E_BRIGHT + 1))
		else
			E_BRIGHT=$((E_BRIGHT - 1))
		fi

		_UPTIME=$((_UPTIME + 1))

		[ "$E_BRIGHT" -gt "$MAX_BRIGHT" ] && E_BRIGHT="$((MAX_BRIGHT - 16))"

		/opt/muos/script/device/bright.sh "$E_BRIGHT"
		B=$((B + 1))
	done
}

if CHARGER_CONNECTED; then
	LOG_INFO "$0" 0 "SUSPEND" "Ignoring suspend while external power is connected"
	exit 0
fi

RECENT_WAKE_SET && exit 0

case "$SHUTDOWN_TIME_SETTING" in
	-2) ;;
	-1) SLEEP && RESUME ;;
	2)
		CHECK_RA_AND_SAVE "CLOSE_CONTENT"
		/opt/muos/script/mux/quit.sh poweroff sleep
		;;
	*)
		S_EPOCH="$RTC_WAKE_PATH/since_epoch"
		W_ALARM="$RTC_WAKE_PATH/wakealarm"

		CURRENT_EPOCH=$(cat "$S_EPOCH")
		WAKE_EPOCH=$((CURRENT_EPOCH + SHUTDOWN_TIME_SETTING))
		echo "$WAKE_EPOCH" >"$W_ALARM"

		SLEEP

		CURRENT_TIME=$(cat "$S_EPOCH")
		if [ "$CURRENT_TIME" -ge "$WAKE_EPOCH" ]; then
			ACTIVITY_TRACKER stop
			CHECK_RA_AND_SAVE "CLOSE_CONTENT"
			/opt/muos/script/mux/quit.sh poweroff sleep
		else
			RESUME
		fi

		echo 0 >"$W_ALARM"
		;;
esac
