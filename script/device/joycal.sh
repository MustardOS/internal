#!/bin/sh

JOYCAL_JSON="/opt/muos/share/conf/joycal.json"
EVDEV_BIN="/usr/bin/evdev-joystick"
JQ_BIN="/usr/bin/jq"

[ -x "$EVDEV_BIN" ] || exit 0
[ -x "$JQ_BIN" ] || exit 0
[ -f "$JOYCAL_JSON" ] || exit 0

DEV_PATH=$("$JQ_BIN" -r '.device_path // empty' "$JOYCAL_JSON")

[ -n "$DEV_PATH" ] || exit 0
[ -e "$DEV_PATH" ] || exit 0

"$JQ_BIN" -r '
  .axes[]? |
  select(.suggested.min != null and .suggested.max != null) |
  [
    .code,
    .suggested.min,
    .suggested.max,
    (.deadzone_suggest // 0)
  ] | @tsv
' "$JOYCAL_JSON" |
	while IFS='	' read -r AXIS MIN MAX DEADZONE; do
		[ -n "$AXIS" ] || continue

		"$EVDEV_BIN" \
			--evdev "$DEV_PATH" \
			--axis "$AXIS" \
			--min "$MIN" \
			--max "$MAX" \
			--deadzone "$DEADZONE" \
			>/dev/null 2>&1
	done

exit 0
