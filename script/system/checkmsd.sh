#!/bin/sh

# https://git.kernel.org/pub/scm/utils/mmc/mmc-utils.git/tree/lsmmc.c
LOOKUP_MANUFACTURER() {
	case "$1" in
		0x000001) echo "Panasonic" ;;
		0x000002) echo "Toshiba/Kingston/Viking" ;;
		0x000003) echo "SanDisk" ;;
		0x000008) echo "Silicon Power" ;;
		0x000018) echo "Infineon" ;;
		0x00001b) echo "Transcend/Samsung" ;;
		0x00001c) echo "Transcend" ;;
		0x00001d) echo "Corsair/AData" ;;
		0x00001e) echo "Transcend" ;;
		0x00001f) echo "Kingston" ;;
		0x000027) echo "Delkin/Phison" ;;
		0x000028) echo "Lexar" ;;
		0x000030) echo "SanDisk" ;;
		0x000031) echo "Silicon Power" ;;
		0x000033) echo "STMicroelectronics" ;;
		0x000041) echo "Kingston" ;;
		0x000045) echo "Team Group" ;;
		0x00006f) echo "STMicroelectronics" ;;
		0x000074) echo "Transcend" ;;
		0x000076) echo "Patriot" ;;
		0x000082) echo "Gobe/Sony" ;;
		0x000088) echo "Foresee/Longsys" ;;
		0x00009c) echo "Angelbird/Hoodman" ;;
		0x0000ad) echo "SK Hynix" ;;
		0x0000e8) echo "GoodRAM" ;;
		*) echo "Unknown ($1)" ;;
	esac
}

INT_DIV_2DP() {
	NUM="$1"
	DEN="$2"

	WHOLE="$((NUM / DEN))"
	FRAC="$(((NUM % DEN) * 100 / DEN))"

	case "$FRAC" in
		[0-9]) FRAC="0${FRAC}" ;;
	esac

	printf '%s.%s' "$WHOLE" "$FRAC"
}

SECTORS_TO_GB() {
	INT_DIV_2DP "$1" 2097152
}

PCT_DIFF_WHOLE() {
	REP_WHOLE="${1%.*}"
	REP_FRAC="${1#*.}"

	PAR_WHOLE="${2%.*}"
	PAR_FRAC="${2#*.}"

	A_SCALED="$((REP_WHOLE * 100 + REP_FRAC))"
	B_SCALED="$((PAR_WHOLE * 100 + PAR_FRAC))"

	DIFF="$((A_SCALED - B_SCALED))"
	[ "$DIFF" -lt 0 ] && DIFF="$((-DIFF))"

	[ "$A_SCALED" -eq 0 ] && {
		echo "0"
		return
	}

	echo "$((DIFF * 100 / A_SCALED))"
}

CHECK_DEVICE() {
	DEVICE="$1"
	OUT_FILE="$2"
	DEV_PATH="/sys/block/$DEVICE"
	DEV_DIR="$DEV_PATH/device"

	[ -d "$DEV_DIR" ] || {
		echo "0"
		return
	}

	SCORE=0

	MANFID="$(cat "$DEV_DIR/manfid" 2>/dev/null)"
	OEMID="$(cat "$DEV_DIR/oemid" 2>/dev/null)"
	SERIAL="$(cat "$DEV_DIR/serial" 2>/dev/null)"
	DATE="$(cat "$DEV_DIR/date" 2>/dev/null)"
	TYPE="$(cat "$DEV_DIR/type" 2>/dev/null)"
	CID="$(cat "$DEV_DIR/cid" 2>/dev/null)"
	NAME="$(cat "$DEV_DIR/name" 2>/dev/null)"
	FWR="$(cat "$DEV_DIR/fwrev" 2>/dev/null)"
	HWREV="$(cat "$DEV_DIR/hwrev" 2>/dev/null)"
	PRE_EOL="$(cat "$DEV_DIR/pre_eol_info" 2>/dev/null)"
	LIFE_TIME="$(cat "$DEV_DIR/life_time" 2>/dev/null)"

	REPORTED_SECTORS="$(cat "$DEV_PATH/size" 2>/dev/null)"
	[ -z "$REPORTED_SECTORS" ] && {
		echo "0"
		return
	}

	MANUFACTURER="$(LOOKUP_MANUFACTURER "$MANFID")"

	PARTITION_SECTORS=0
	for PART_SIZE_FILE in "$DEV_PATH/${DEVICE}p"*/size; do
		[ -f "$PART_SIZE_FILE" ] || continue
		PART_S="$(cat "$PART_SIZE_FILE" 2>/dev/null)"
		PARTITION_SECTORS="$((PARTITION_SECTORS + ${PART_S:-0}))"
	done

	[ "$PARTITION_SECTORS" -eq 0 ] && SCORE="$((SCORE + 5))"

	REPORTED_GB="$(SECTORS_TO_GB "$REPORTED_SECTORS")"
	PARTITION_GB="$(SECTORS_TO_GB "$PARTITION_SECTORS")"

	case "$MANUFACTURER" in
		Unknown*)
			SCORE="$((SCORE + 4))"
			echo "WARN: Unknown manufacturer ID ($MANFID)" >>"$OUT_FILE"
			;;
		*)
			echo "INFO: Manufacturer: $MANUFACTURER ($MANFID)" >>"$OUT_FILE"
			;;
	esac

	case "$OEMID" in
		0x0000 | 0xffff | "")
			SCORE="$((SCORE + 3))"
			echo "WARN: Suspicious OEM ID ($OEMID)" >>"$OUT_FILE"
			;;
		*)
			echo "INFO: OEM ID: $OEMID" >>"$OUT_FILE"
			;;
	esac

	case "$SERIAL" in
		0x00000000 | 0xffffffff)
			SCORE="$((SCORE + 5))"
			echo "WARN: Invalid serial number ($SERIAL)" >>"$OUT_FILE"
			;;
		*)
			echo "INFO: Serial: $SERIAL" >>"$OUT_FILE"
			;;
	esac

	case "$DATE" in
		"" | "0/0" | "1/0")
			SCORE="$((SCORE + 3))"
			echo "WARN: Invalid/missing manufacturing date ($DATE)" >>"$OUT_FILE"
			;;
		*)
			echo "INFO: Manufacturing date: $DATE" >>"$OUT_FILE"
			;;
	esac

	case "$CID" in
		00000000000000000000000000000000)
			SCORE="$((SCORE + 10))"
			echo "WARN: CID is all zeros - strong fake indicator" >>"$OUT_FILE"
			;;
		*)
			# Crossvalidate CID manufacturer byte against manfid
			CID_MID="0x0000$(echo "$CID" | cut -c1-2)"
			if [ -n "$MANFID" ] && [ "$CID_MID" != "$MANFID" ]; then
				SCORE="$((SCORE + 5))"
				echo "WARN: CID manufacturer byte ($CID_MID) mismatches manfid ($MANFID)" >>"$OUT_FILE"
			else
				echo "INFO: CID: $CID" >>"$OUT_FILE"
			fi
			;;
	esac

	case "$TYPE" in
		SD | MMC | SDIO)
			echo "INFO: Card type: $TYPE" >>"$OUT_FILE"
			;;
		"")
			SCORE="$((SCORE + 2))"
			echo "WARN: Missing card type" >>"$OUT_FILE"
			;;
		*)
			SCORE="$((SCORE + 1))"
			echo "WARN: Unexpected card type ($TYPE)" >>"$OUT_FILE"
			;;
	esac

	if [ -z "$NAME" ]; then
		SCORE="$((SCORE + 2))"
		echo "WARN: Missing card name/model" >>"$OUT_FILE"
	else
		echo "INFO: Card name: $NAME" >>"$OUT_FILE"
	fi

	# Firmware and hardware revision.  Having both zero simultaneously is unusual
	if [ "$FWR" = "0x0" ] && [ "$HWREV" = "0x0" ]; then
		SCORE="$((SCORE + 2))"
		echo "WARN: Both fwrev and hwrev are zero" >>"$OUT_FILE"
	else
		echo "INFO: FW rev: $FWR  HW rev: $HWREV" >>"$OUT_FILE"
	fi

	CAP_DIFF="$(PCT_DIFF_WHOLE "$REPORTED_GB" "$PARTITION_GB")"
	echo "INFO: Reported: ${REPORTED_GB}GB  Partitioned: ${PARTITION_GB}GB  Diff: ${CAP_DIFF}%" >>"$OUT_FILE"
	if [ "$CAP_DIFF" -gt 40 ]; then
		SCORE="$((SCORE + 10))"
		echo "WARN: Capacity mismatch >40% - strong fake indicator" >>"$OUT_FILE"
	elif [ "$CAP_DIFF" -gt 10 ]; then
		SCORE="$((SCORE + 4))"
		echo "WARN: Capacity mismatch >10%" >>"$OUT_FILE"
	fi

	# Capacity plausibility. Real cards ship in standard p^2 sizes
	NEAREST_DIFF=9999
	for SZ in "512.00" "256.00" "128.00" "64.00" "32.00" "16.00" "8.00" "4.00" "2.00" "1.00"; do
		D="$(PCT_DIFF_WHOLE "$REPORTED_GB" "$SZ")"
		[ "$D" -lt "$NEAREST_DIFF" ] && NEAREST_DIFF="$D"
	done
	if [ "$NEAREST_DIFF" -gt 15 ]; then
		SCORE="$((SCORE + 3))"
		echo "WARN: Reported capacity (${REPORTED_GB}GB) not near any standard size" >>"$OUT_FILE"
	else
		echo "INFO: Capacity near a standard size (${NEAREST_DIFF}% from nearest)" >>"$OUT_FILE"
	fi

	# Pre-EOL info
	case "$PRE_EOL" in
		0x01) echo "INFO: Pre-EOL: Normal" >>"$OUT_FILE" ;;
		0x02)
			SCORE="$((SCORE + 2))"
			echo "WARN: Pre-EOL: Warning (device nearing end of life)" >>"$OUT_FILE"
			;;
		0x03)
			SCORE="$((SCORE + 5))"
			echo "WARN: Pre-EOL: Urgent (device at end of life)" >>"$OUT_FILE"
			;;
		*)
			echo "INFO: Pre-EOL: Not reported ($PRE_EOL)" >>"$OUT_FILE"
			;;
	esac

	# Wear levelling. Wildly mismatched indicators suggest fake reporting (maybe)
	if [ -n "$LIFE_TIME" ]; then
		LIFE_A="${LIFE_TIME%% *}"
		LIFE_B="${LIFE_TIME##* }"
		if [ -n "$LIFE_A" ] && [ -n "$LIFE_B" ] && [ "$LIFE_A" != "$LIFE_B" ]; then
			WEAR_DIFF="$((LIFE_A - LIFE_B))"
			[ "$WEAR_DIFF" -lt 0 ] && WEAR_DIFF="$((-WEAR_DIFF))"
			if [ "$WEAR_DIFF" -gt 3 ]; then
				SCORE="$((SCORE + 2))"
				echo "WARN: Wear indicators mismatched (A=$LIFE_A B=$LIFE_B diff=$WEAR_DIFF)" >>"$OUT_FILE"
			else
				echo "INFO: Wear indicators: A=$LIFE_A B=$LIFE_B" >>"$OUT_FILE"
			fi
		fi
	fi

	echo "$SCORE"
}

HIGHEST_SCORE=0

CHK_DIR="/tmp/msd_check"
mkdir -p "$CHK_DIR"

for DEV in /sys/block/mmcblk*; do
	[ -d "$DEV" ] || continue

	DEVNAME="${DEV##*/}"
	OUT_FILE="$CHK_DIR/$DEVNAME"

	: >"$OUT_FILE"
	SCORE="$(CHECK_DEVICE "$DEVNAME" "$OUT_FILE")"

	if [ "$SCORE" -ge 100 ]; then
		VERDICT="TRASH"
	elif [ "$SCORE" -ge 12 ]; then
		VERDICT="FAKE"
	elif [ "$SCORE" -ge 9 ]; then
		VERDICT="SUSPECTED_FAKE"
	elif [ "$SCORE" -ge 5 ]; then
		VERDICT="SUSPICIOUS"
	elif [ "$SCORE" -ge 1 ]; then
		VERDICT="LIKELY_GENUINE"
	else
		VERDICT="GENUINE"
	fi

	DETAILS="$(cat "$OUT_FILE")"
	printf '%s %d\n%s\n' "$VERDICT" "$SCORE" "$DETAILS" >"$OUT_FILE"

	[ "$SCORE" -gt "$HIGHEST_SCORE" ] && HIGHEST_SCORE="$SCORE"
done

[ "$HIGHEST_SCORE" -gt 254 ] && HIGHEST_SCORE=254

exit "$HIGHEST_SCORE"
