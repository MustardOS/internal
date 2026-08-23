#!/bin/sh

. /opt/muos/script/var/func.sh

# Everything arrives on the first core by default, so the core most likely to
# be running the game also handles every card, display and radio interrupt.
#
# So what this will try and do is spread those interrupts over the
# remaining cores leaves the first one for the work.
#
# Interrupts that cannot be steered, the per CPU timers and the like, simply
# refuse the write and are skipped...

AFFINITY_DIR="/proc/irq"

CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
case "$CPU_COUNT" in
	'' | *[!0-9]*) CPU_COUNT=1 ;;
esac

if [ "$CPU_COUNT" -lt 3 ]; then
	LOG_INFO "$0" 0 "IRQ" "$(printf "Only %s cores, leaving interrupts where they are" "$CPU_COUNT")"
	exit 0
fi

MOVED=0
SKIPPED=0
NEXT=1

for IRQ_PATH in "$AFFINITY_DIR"/*/smp_affinity_list; do
	[ -w "$IRQ_PATH" ] || continue

	IRQ_NUM=$(basename "$(dirname "$IRQ_PATH")")
	case "$IRQ_NUM" in
		'' | *[!0-9]*) continue ;;
	esac

	IRQ_HITS=$(awk -v n="$IRQ_NUM:" '$1 == n { for (i = 2; i <= NF; i++) if ($i ~ /^[0-9]+$/) t += $i; print t + 0; exit }' /proc/interrupts)
	case "$IRQ_HITS" in
		'' | 0) continue ;;
	esac

	if printf "%s" "$NEXT" >"$IRQ_PATH" 2>/dev/null; then
		MOVED=$((MOVED + 1))
	else
		SKIPPED=$((SKIPPED + 1))
	fi

	NEXT=$((NEXT + 1))
	[ "$NEXT" -ge "$CPU_COUNT" ] && NEXT=1
done

LOG_INFO "$0" 0 "IRQ" "$(printf "Spread %s interrupts over cores 1 to %s, %s could not be moved" "$MOVED" "$((CPU_COUNT - 1))" "$SKIPPED")"
