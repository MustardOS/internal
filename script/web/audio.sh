#!/bin/sh

# Streams the sound the device is playing to stdout for Live Remote View, as raw
# signed 16-bit little endian stereo at the rate muweb passes in. muweb hands the
# browser connection to this script, so the capture stops when the viewer leaves.

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}"

RATE=${1:-24000}
case "$RATE" in
	'' | *[!0-9]*) RATE=24000 ;;
esac

# Newer PipeWire writes a sound file header to stdout unless asked for raw samples
RAW=""
pw-record --help 2>&1 | grep -q -- "--raw" && RAW="--raw"

# shellcheck disable=SC2086
exec pw-record -P "{ stream.capture.sink=true node.name=muweb-live-sound }" \
	--latency 20ms --rate "$RATE" --channels 2 --format s16 $RAW - 2>/dev/null
