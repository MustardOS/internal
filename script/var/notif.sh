#!/bin/sh
# =============================================================================
# notif.sh -- MustardOS Overlay Notification Library
# =============================================================================
#
# USAGE
#   Source this file then call any NOTIF_* function:
#
#     . /path/to/notif.sh
#
# =============================================================================
# THE NOTIFICATION FILE
# =============================================================================
#
#   Notifications are written to /run/muos/overlay.notif and picked up by the
#   MustardOS overlay renderer automatically on the next frame.  Deleting the
#   file clears the notification.  The file format is:
#
#     position      = 4        (0-8 grid, see POSITION below)
#     font_size     = 24       (8-96)
#     font_align    = 0        (0=auto  1=right  2=centre  3=left)
#     font_colour   = FFFFFF   (hex RGB, no #)
#     font_alpha    = 255      (0-255)
#     box_colour    = 000000   (hex RGB)
#     box_alpha     = 210      (0-255)
#     border_colour = 444444   (hex RGB)
#     border_alpha  = 180      (0-255)
#     dim_colour    = 000000   (hex RGB, full-screen tint behind the box)
#     dim_alpha     = 0        (0=no dim, 255=fully opaque tint)
#     -
#     First line of text
#     Second line of text
#
#     A blank line above creates a visual gap in the box.
#
# =============================================================================
# POSITION GRID
# =============================================================================
#
#   0  1  2      0 = top-left      1 = top-centre      2 = top-right
#   3  4  5      3 = middle-left   4 = centre           5 = middle-right
#   6  7  8      6 = bottom-left   7 = bottom-centre   8 = bottom-right
#
# =============================================================================
# DEFAULTS
# =============================================================================
#
#   These variables control the base style used by every function.
#   Override them before calling any function to change the global look:
#
#     NOTIF_DEF_POSITION=4
#     NOTIF_DEF_FONT_SIZE=24
#     NOTIF_DEF_FONT_ALIGN=0
#     NOTIF_DEF_FONT_COLOUR="FFFFFF"
#     NOTIF_DEF_FONT_ALPHA=255
#     NOTIF_DEF_BOX_COLOUR="000000"
#     NOTIF_DEF_BOX_ALPHA=210
#     NOTIF_DEF_BORDER_COLOUR="444444"
#     NOTIF_DEF_BORDER_ALPHA=180
#     NOTIF_DEF_DIM_COLOUR="000000"
#     NOTIF_DEF_DIM_ALPHA=0
#
# =============================================================================
# STYLE STRINGS  (the combining mechanism)
# =============================================================================
#
#   Every display function accepts an optional STYLE argument as its last
#   parameter.  A style string is one or more colon-separated tokens.  Each
#   token is either a named preset or a key=value pair:
#
#     Named presets:  info  success  warn  error  critical  hint
#
#     Key=value pairs (same keys as the file format):
#       position=N  font_size=N  font_align=N
#       font_colour=RRGGBB  font_alpha=N
#       box_colour=RRGGBB   box_alpha=N
#       border_colour=RRGGBB  border_alpha=N
#       dim_colour=RRGGBB   dim_alpha=N
#
#   Tokens are applied left to right, so later tokens override earlier ones.
#   An empty string "" leaves the defaults untouched.
#
#   Examples:
#
#     NOTIF_SHOW   "Hello"  "warn"
#     NOTIF_FLASH  3 "Alert!" "error"
#     NOTIF_FLASH  3 "Alert!" "error:border_colour=FF8800"
#     NOTIF_TOAST  "Saved"   "success:position=1"
#     NOTIF_COUNTDOWN 5 "Reboot in %d..." "warn:dim_alpha=80"
#     NOTIF_SPINNER 4 "Working..." "info:font_size=20"
#     NOTIF_SHOW   "Custom" "border_colour=FF0000:box_alpha=240:dim_alpha=60"
#
#   Combining a preset with a timed function creates a single expressive call:
#
#     NOTIF_SHOW_TIMED 3 "Done!" "success"
#     NOTIF_DIM_PULSE  2 "Attention" "warn:dim_alpha=160"
#     NOTIF_RAINBOW    3 "Party!" ""
#
# =============================================================================
# BUILDER API
# =============================================================================
#
#   For multi-line notifications or fine-grained control use the builder:
#
#     NOTIF_BUILD_START
#     NOTIF_BUILD_STYLE "warn"              (optional: apply a style preset)
#     NOTIF_BUILD_SET   border_colour FF0000 (optional: override individual keys)
#     NOTIF_BUILD_ADD   "Line one"
#     NOTIF_BUILD_ADD   ""                  (blank line = visual gap)
#     NOTIF_BUILD_ADD   "Line after gap"
#     NOTIF_BUILD_SEND
#     NOTIF_BUILD_RESET
#
#   NOTIF_BUILD_PREVIEW prints the file that would be written without writing.
#
# =============================================================================
# FUNCTION REFERENCE
# =============================================================================
#
#   CORE
#     NOTIF_CLEAR                           Remove notification immediately
#     NOTIF_SHOW          <msg> [style]     Single line, default position
#     NOTIF_SHOW_AT       <pos> <msg> [style]   Explicit grid position
#     NOTIF_SHOW_TIMED    <s> <msg> [style] Show then clear after N seconds
#     NOTIF_MULTILINE     <line>... [style] Multiple lines as arguments
#
#   SEMANTIC PRESETS  (also usable as style names)
#     NOTIF_INFO          <msg>             Blue-tinted informational
#     NOTIF_SUCCESS       <msg>             Green confirmation
#     NOTIF_WARN          <msg>             Amber warning
#     NOTIF_ERROR         <msg>             Red error with dim
#     NOTIF_CRITICAL      <msg>             Large red, full dim
#     NOTIF_HINT          <msg>             Subtle small bottom hint
#     NOTIF_TOAST         <msg> [style]     Bottom-centre, auto-clears 2s
#     NOTIF_BANNER        <msg> [style]     Top-centre larger text
#
#   FLASHERS
#     NOTIF_FLASH         <n> <msg> [style] [on_ms] [off_ms]
#     NOTIF_FLASH_STYLED  <n> <fc> <bc> <bdc> <msg>
#     NOTIF_BORDER_FLASH  <n> <col> <msg> [style]
#     NOTIF_STROBE        <n> <col_a> <col_b> <msg> [style]
#
#   DIM EFFECTS
#     NOTIF_DIM_FADE_IN   <alpha> <steps> <msg> [style]
#     NOTIF_DIM_FADE_OUT  <alpha> <steps> <msg> [style]
#     NOTIF_DIM_PULSE     <n> <msg> [style] [peak_alpha]
#     NOTIF_DIM_COLOUR_SHIFT <from> <to> <steps> <msg>
#
#   COLOUR TRANSITIONS
#     NOTIF_FADE_IN       <steps> <msg> [style]
#     NOTIF_FADE_OUT      <steps> <msg> [style]
#     NOTIF_CROSSFADE     <steps> <from_msg> <to_msg> [style]
#     NOTIF_COLOUR_SHIFT  <from_hex> <to_hex> <steps> <msg>
#
#   LIVE UPDATERS
#     NOTIF_COUNTDOWN     <s> <fmt> [style]
#     NOTIF_COUNTUP       <s> <fmt> [style]
#     NOTIF_PROGRESS      <mn> <mx> <val> <lbl> [style]
#     NOTIF_PROGRESS_LOOP <mn> <mx> <step> <delay_ms> <lbl> [style]
#     NOTIF_SPINNER       <s> <msg> [style]
#     NOTIF_TYPEWRITER    <delay_s> <msg> [style]
#     NOTIF_WATCH_FILE    <file> <fmt> [interval_s] [style]
#     NOTIF_WATCH_CMD     <cmd> <fmt> [interval_s] [style]
#
#   FUN / NOVELTY
#     NOTIF_RAINBOW       <n> <msg>
#     NOTIF_POLICE        <n> <msg>
#     NOTIF_GLITCH        <n> <msg>
#     NOTIF_SLIDE_IN      <from_pos> <to_pos> <steps> <msg> [style]
#     NOTIF_BOUNCE        <n> <pos_a> <pos_b> <msg> [style]
#
#   STRING BUILDERS  (return values to stdout, no side effects)
#     NOTIF_STR_BAR       <min> <max> <val> <width>
#     NOTIF_STR_DOTS      <n> [char]
#     NOTIF_STR_CENTRE    <width> <text>
#     NOTIF_STR_TRUNCATE  <max> <text> [suffix]
#     NOTIF_STR_WRAP      <max> <text>
#     NOTIF_STR_REPEAT    <n> <str>
#     NOTIF_STR_UPPER     <text>
#     NOTIF_STR_LOWER     <text>
#     NOTIF_STR_TIMESTAMP
#     NOTIF_STR_ELAPSED   <start_epoch>
#     NOTIF_STR_FILESIZE  <bytes>
#
#   SYSTEM
#     NOTIF_BATTERY       [style]
#     NOTIF_UPTIME        [style]
#     NOTIF_IP            [style]
#     NOTIF_STORAGE       [path] [style]
#     NOTIF_DATE_TIME     [style]
#     NOTIF_CONFIRM       <msg> [style]
#     NOTIF_HELP
#
# =============================================================================

NOTIF_PATH="/run/muos/overlay.notif"

NOTIF_DEF_POSITION=4
NOTIF_DEF_FONT_SIZE=24
NOTIF_DEF_FONT_ALIGN=0
NOTIF_DEF_FONT_COLOUR="FFFFFF"
NOTIF_DEF_FONT_ALPHA=255
NOTIF_DEF_BOX_COLOUR="000000"
NOTIF_DEF_BOX_ALPHA=210
NOTIF_DEF_BORDER_COLOUR="444444"
NOTIF_DEF_BORDER_ALPHA=180
NOTIF_DEF_DIM_COLOUR="000000"
NOTIF_DEF_DIM_ALPHA=0

NOTIF_ST_POSITION="$NOTIF_DEF_POSITION"
NOTIF_ST_FONT_SIZE="$NOTIF_DEF_FONT_SIZE"
NOTIF_ST_FONT_ALIGN="$NOTIF_DEF_FONT_ALIGN"
NOTIF_ST_FONT_COLOUR="$NOTIF_DEF_FONT_COLOUR"
NOTIF_ST_FONT_ALPHA="$NOTIF_DEF_FONT_ALPHA"
NOTIF_ST_BOX_COLOUR="$NOTIF_DEF_BOX_COLOUR"
NOTIF_ST_BOX_ALPHA="$NOTIF_DEF_BOX_ALPHA"
NOTIF_ST_BORDER_COLOUR="$NOTIF_DEF_BORDER_COLOUR"
NOTIF_ST_BORDER_ALPHA="$NOTIF_DEF_BORDER_ALPHA"
NOTIF_ST_DIM_COLOUR="$NOTIF_DEF_DIM_COLOUR"
NOTIF_ST_DIM_ALPHA="$NOTIF_DEF_DIM_ALPHA"

NOTIF_STYLE_RESET() {
	NOTIF_ST_POSITION="$NOTIF_DEF_POSITION"
	NOTIF_ST_FONT_SIZE="$NOTIF_DEF_FONT_SIZE"
	NOTIF_ST_FONT_ALIGN="$NOTIF_DEF_FONT_ALIGN"
	NOTIF_ST_FONT_COLOUR="$NOTIF_DEF_FONT_COLOUR"
	NOTIF_ST_FONT_ALPHA="$NOTIF_DEF_FONT_ALPHA"
	NOTIF_ST_BOX_COLOUR="$NOTIF_DEF_BOX_COLOUR"
	NOTIF_ST_BOX_ALPHA="$NOTIF_DEF_BOX_ALPHA"
	NOTIF_ST_BORDER_COLOUR="$NOTIF_DEF_BORDER_COLOUR"
	NOTIF_ST_BORDER_ALPHA="$NOTIF_DEF_BORDER_ALPHA"
	NOTIF_ST_DIM_COLOUR="$NOTIF_DEF_DIM_COLOUR"
	NOTIF_ST_DIM_ALPHA="$NOTIF_DEF_DIM_ALPHA"
}

NOTIF_STYLE_APPLY_TOKEN() {
	case "$1" in
		info)
			NOTIF_ST_FONT_COLOUR="DDEEFF"
			NOTIF_ST_FONT_ALPHA=255
			NOTIF_ST_BOX_COLOUR="0A1A2A"
			NOTIF_ST_BOX_ALPHA=220
			NOTIF_ST_BORDER_COLOUR="4488CC"
			NOTIF_ST_BORDER_ALPHA=200
			NOTIF_ST_DIM_COLOUR="000000"
			NOTIF_ST_DIM_ALPHA=0
			NOTIF_ST_FONT_ALIGN=2
			;;
		success)
			NOTIF_ST_FONT_COLOUR="CCFFCC"
			NOTIF_ST_FONT_ALPHA=255
			NOTIF_ST_BOX_COLOUR="0A1A0A"
			NOTIF_ST_BOX_ALPHA=220
			NOTIF_ST_BORDER_COLOUR="44AA44"
			NOTIF_ST_BORDER_ALPHA=200
			NOTIF_ST_DIM_COLOUR="000000"
			NOTIF_ST_DIM_ALPHA=0
			NOTIF_ST_FONT_ALIGN=2
			;;
		warn)
			NOTIF_ST_FONT_COLOUR="FFE066"
			NOTIF_ST_FONT_ALPHA=255
			NOTIF_ST_BOX_COLOUR="1A1200"
			NOTIF_ST_BOX_ALPHA=220
			NOTIF_ST_BORDER_COLOUR="BBAA00"
			NOTIF_ST_BORDER_ALPHA=210
			NOTIF_ST_DIM_COLOUR="1A0A00"
			NOTIF_ST_DIM_ALPHA=80
			NOTIF_ST_FONT_ALIGN=2
			;;
		error)
			NOTIF_ST_FONT_COLOUR="FFAAAA"
			NOTIF_ST_FONT_ALPHA=255
			NOTIF_ST_BOX_COLOUR="1A0000"
			NOTIF_ST_BOX_ALPHA=230
			NOTIF_ST_BORDER_COLOUR="CC2222"
			NOTIF_ST_BORDER_ALPHA=220
			NOTIF_ST_DIM_COLOUR="1A0000"
			NOTIF_ST_DIM_ALPHA=120
			NOTIF_ST_FONT_ALIGN=2
			;;
		critical)
			NOTIF_ST_FONT_SIZE=32
			NOTIF_ST_FONT_COLOUR="FFFFFF"
			NOTIF_ST_FONT_ALPHA=255
			NOTIF_ST_BOX_COLOUR="220000"
			NOTIF_ST_BOX_ALPHA=240
			NOTIF_ST_BORDER_COLOUR="FF0000"
			NOTIF_ST_BORDER_ALPHA=255
			NOTIF_ST_DIM_COLOUR="440000"
			NOTIF_ST_DIM_ALPHA=180
			NOTIF_ST_FONT_ALIGN=2
			;;
		hint)
			NOTIF_ST_FONT_SIZE=18
			NOTIF_ST_FONT_COLOUR="AAAAAA"
			NOTIF_ST_FONT_ALPHA=200
			NOTIF_ST_BOX_COLOUR="000000"
			NOTIF_ST_BOX_ALPHA=160
			NOTIF_ST_BORDER_COLOUR="333333"
			NOTIF_ST_BORDER_ALPHA=120
			NOTIF_ST_DIM_COLOUR="000000"
			NOTIF_ST_DIM_ALPHA=0
			NOTIF_ST_POSITION=7
			NOTIF_ST_FONT_ALIGN=2
			;;
		position=*) NOTIF_ST_POSITION="${1#position=}" ;;
		font_size=*) NOTIF_ST_FONT_SIZE="${1#font_size=}" ;;
		font_align=*) NOTIF_ST_FONT_ALIGN="${1#font_align=}" ;;
		font_colour=*) NOTIF_ST_FONT_COLOUR="${1#font_colour=}" ;;
		font_alpha=*) NOTIF_ST_FONT_ALPHA="${1#font_alpha=}" ;;
		box_colour=*) NOTIF_ST_BOX_COLOUR="${1#box_colour=}" ;;
		box_alpha=*) NOTIF_ST_BOX_ALPHA="${1#box_alpha=}" ;;
		border_colour=*) NOTIF_ST_BORDER_COLOUR="${1#border_colour=}" ;;
		border_alpha=*) NOTIF_ST_BORDER_ALPHA="${1#border_alpha=}" ;;
		dim_colour=*) NOTIF_ST_DIM_COLOUR="${1#dim_colour=}" ;;
		dim_alpha=*) NOTIF_ST_DIM_ALPHA="${1#dim_alpha=}" ;;
	esac
}

NOTIF_STYLE_APPLY() {
	NOTIF_STYLE_RESET
	SA_STR="$1"
	while [ -n "$SA_STR" ]; do
		SA_TOKEN="${SA_STR%%:*}"
		NOTIF_STYLE_APPLY_TOKEN "$SA_TOKEN"
		[ "$SA_STR" = "$SA_TOKEN" ] && break
		SA_STR="${SA_STR#*:}"
	done
}

NOTIF_WRITE() {
	NW_POS="$1"
	shift
	NW_FS="$1"
	shift
	NW_FA="$1"
	shift
	NW_FC="$1"
	shift
	NW_FAL="$1"
	shift
	NW_BC="$1"
	shift
	NW_BAL="$1"
	shift
	NW_BDC="$1"
	shift
	NW_BDAL="$1"
	shift
	NW_DC="$1"
	shift
	NW_DAL="$1"
	shift
	{
		printf 'position      = %s\n' "$NW_POS"
		printf 'font_size     = %s\n' "$NW_FS"
		printf 'font_align    = %s\n' "$NW_FA"
		printf 'font_colour   = %s\n' "$NW_FC"
		printf 'font_alpha    = %s\n' "$NW_FAL"
		printf 'box_colour    = %s\n' "$NW_BC"
		printf 'box_alpha     = %s\n' "$NW_BAL"
		printf 'border_colour = %s\n' "$NW_BDC"
		printf 'border_alpha  = %s\n' "$NW_BDAL"
		printf 'dim_colour    = %s\n' "$NW_DC"
		printf 'dim_alpha     = %s\n' "$NW_DAL"
		printf '%s\n' '-'
		for NW_LINE in "$@"; do
			printf '%s\n' "$NW_LINE"
		done
	} >"$NOTIF_PATH"
}

NOTIF_WRITE_ST() {
	NOTIF_WRITE \
		"$NOTIF_ST_POSITION" \
		"$NOTIF_ST_FONT_SIZE" \
		"$NOTIF_ST_FONT_ALIGN" \
		"$NOTIF_ST_FONT_COLOUR" \
		"$NOTIF_ST_FONT_ALPHA" \
		"$NOTIF_ST_BOX_COLOUR" \
		"$NOTIF_ST_BOX_ALPHA" \
		"$NOTIF_ST_BORDER_COLOUR" \
		"$NOTIF_ST_BORDER_ALPHA" \
		"$NOTIF_ST_DIM_COLOUR" \
		"$NOTIF_ST_DIM_ALPHA" \
		"$@"
}

NOTIF_SLEEP() {
	sleep "$1" 2>/dev/null || sleep 1
}

NOTIF_LERP_BYTE() {
	awk "BEGIN { printf \"%d\", int($1 + ($2 - $1) * $3 / $4 + 0.5) }"
}

NOTIF_HEX2R() {
	printf '%d' "0x${1%????}"
}

NOTIF_HEX2G() {
	HEX2G_H="${1#??}"
	printf '%d' "0x${HEX2G_H%??}"
}

NOTIF_HEX2B() {
	printf '%d' "0x${1#????}"
}

NOTIF_RGB2HEX() {
	printf '%02X%02X%02X' "$1" "$2" "$3"
}

NOTIF_CLAMP() {
	awk "BEGIN { v=$1; if(v<$2) v=$2; if(v>$3) v=$3; print int(v) }"
}

NOTIF_CLEAR() {
	rm -f "$NOTIF_PATH"
}

NOTIF_SHOW() {
	NOTIF_STYLE_APPLY "${2:-}"
	NOTIF_WRITE_ST "$1"
}

NOTIF_SHOW_AT() {
	NOTIF_STYLE_APPLY "${3:-}"
	NOTIF_ST_POSITION="$1"
	NOTIF_WRITE_ST "$2"
}

NOTIF_SHOW_TIMED() {
	NOTIF_STYLE_APPLY "${3:-}"
	NOTIF_WRITE_ST "$2"
	NOTIF_SLEEP "$1"
	NOTIF_CLEAR
}

NOTIF_MULTILINE() {
	NOTIF_STYLE_RESET
	NOTIF_WRITE_ST "$@"
}

NOTIF_INFO() {
	NOTIF_STYLE_APPLY "info"
	NOTIF_WRITE_ST "$1"
}

NOTIF_SUCCESS() {
	NOTIF_STYLE_APPLY "success"
	NOTIF_WRITE_ST "$1"
}

NOTIF_WARN() {
	NOTIF_STYLE_APPLY "warn"
	NOTIF_WRITE_ST "$1"
}

NOTIF_ERROR() {
	NOTIF_STYLE_APPLY "error"
	NOTIF_WRITE_ST "$1"
}

NOTIF_CRITICAL() {
	NOTIF_STYLE_APPLY "critical"
	NOTIF_WRITE_ST "$1"
}

NOTIF_HINT() {
	NOTIF_STYLE_APPLY "hint"
	NOTIF_WRITE_ST "$1"
}

NOTIF_TOAST() {
	NOTIF_STYLE_APPLY "${2:-}"
	NOTIF_ST_POSITION=7
	NOTIF_WRITE_ST "$1"
	NOTIF_SLEEP 2
	NOTIF_CLEAR
}

NOTIF_BANNER() {
	NOTIF_STYLE_APPLY "${2:-}"
	NOTIF_ST_POSITION=1
	NOTIF_ST_FONT_SIZE=28
	NOTIF_ST_FONT_ALIGN=2
	NOTIF_WRITE_ST "$1"
}

NOTIF_FLASH() {
	NF_COUNT="$1"
	NF_MSG="$2"
	NF_STYLE="${3:-}"
	NF_ON="${4:-400}"
	NF_OFF="${5:-200}"
	NF_I=0
	while [ "$NF_I" -lt "$NF_COUNT" ]; do
		NOTIF_STYLE_APPLY "$NF_STYLE"
		NOTIF_WRITE_ST "$NF_MSG"
		NOTIF_SLEEP "$(awk "BEGIN { printf \"%.3f\", $NF_ON/1000 }")"
		NOTIF_CLEAR
		NOTIF_SLEEP "$(awk "BEGIN { printf \"%.3f\", $NF_OFF/1000 }")"
		NF_I=$((NF_I + 1))
	done
}

NOTIF_FLASH_STYLED() {
	NFS_COUNT="$1"
	NFS_FC="$2"
	NFS_BC="$3"
	NFS_BDC="$4"
	NFS_MSG="$5"
	NFS_I=0
	while [ "$NFS_I" -lt "$NFS_COUNT" ]; do
		NOTIF_STYLE_RESET
		NOTIF_ST_FONT_COLOUR="$NFS_FC"
		NOTIF_ST_BOX_COLOUR="$NFS_BC"
		NOTIF_ST_BORDER_COLOUR="$NFS_BDC"
		NOTIF_ST_FONT_ALIGN=2
		NOTIF_WRITE_ST "$NFS_MSG"
		NOTIF_SLEEP 0.4
		NOTIF_CLEAR
		NOTIF_SLEEP 0.2
		NFS_I=$((NFS_I + 1))
	done
}

NOTIF_BORDER_FLASH() {
	NBF_COUNT="$1"
	NBF_COL="$2"
	NBF_MSG="$3"
	NBF_STYLE="${4:-}"
	NBF_I=0
	while [ "$NBF_I" -lt "$NBF_COUNT" ]; do
		NOTIF_STYLE_APPLY "$NBF_STYLE"
		NOTIF_ST_BORDER_COLOUR="$NBF_COL"
		NOTIF_ST_BORDER_ALPHA=255
		NOTIF_WRITE_ST "$NBF_MSG"
		NOTIF_SLEEP 0.35
		NOTIF_STYLE_APPLY "$NBF_STYLE"
		NOTIF_ST_BORDER_ALPHA=30
		NOTIF_WRITE_ST "$NBF_MSG"
		NOTIF_SLEEP 0.25
		NBF_I=$((NBF_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_STROBE() {
	NS_COUNT="$1"
	NS_CA="$2"
	NS_CB="$3"
	NS_MSG="$4"
	NS_STYLE="${5:-}"
	NS_I=0
	while [ "$NS_I" -lt "$NS_COUNT" ]; do
		NOTIF_STYLE_APPLY "$NS_STYLE"
		NOTIF_ST_BOX_COLOUR="$NS_CA"
		NOTIF_ST_FONT_ALIGN=2
		NOTIF_WRITE_ST "$NS_MSG"
		NOTIF_SLEEP 0.15
		NOTIF_STYLE_APPLY "$NS_STYLE"
		NOTIF_ST_BOX_COLOUR="$NS_CB"
		NOTIF_ST_FONT_ALIGN=2
		NOTIF_WRITE_ST "$NS_MSG"
		NOTIF_SLEEP 0.15
		NS_I=$((NS_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_DIM_FADE_IN() {
	DFI_TARGET="$1"
	DFI_STEPS="$2"
	DFI_MSG="$3"
	DFI_STYLE="${4:-}"
	DFI_I=0
	while [ "$DFI_I" -le "$DFI_STEPS" ]; do
		NOTIF_STYLE_APPLY "$DFI_STYLE"
		NOTIF_ST_DIM_ALPHA="$(NOTIF_LERP_BYTE 0 "$DFI_TARGET" "$DFI_I" "$DFI_STEPS")"
		NOTIF_WRITE_ST "$DFI_MSG"
		NOTIF_SLEEP 0.05
		DFI_I=$((DFI_I + 1))
	done
}

NOTIF_DIM_FADE_OUT() {
	DFO_FROM="$1"
	DFO_STEPS="$2"
	DFO_MSG="$3"
	DFO_STYLE="${4:-}"
	DFO_I=0
	while [ "$DFO_I" -le "$DFO_STEPS" ]; do
		NOTIF_STYLE_APPLY "$DFO_STYLE"
		NOTIF_ST_DIM_ALPHA="$(NOTIF_LERP_BYTE "$DFO_FROM" 0 "$DFO_I" "$DFO_STEPS")"
		NOTIF_WRITE_ST "$DFO_MSG"
		NOTIF_SLEEP 0.05
		DFO_I=$((DFO_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_DIM_PULSE() {
	DP_COUNT="$1"
	DP_MSG="$2"
	DP_STYLE="${3:-}"
	DP_PEAK="${4:-140}"
	DP_STEPS=10
	DP_I=0
	while [ "$DP_I" -lt "$DP_COUNT" ]; do
		NOTIF_DIM_FADE_IN "$DP_PEAK" "$DP_STEPS" "$DP_MSG" "$DP_STYLE"
		NOTIF_DIM_FADE_OUT "$DP_PEAK" "$DP_STEPS" "$DP_MSG" "$DP_STYLE"
		DP_I=$((DP_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_DIM_COLOUR_SHIFT() {
	DCS_FROM="$1"
	DCS_TO="$2"
	DCS_STEPS="$3"
	DCS_MSG="$4"
	DCS_FR=$(NOTIF_HEX2R "$DCS_FROM")
	DCS_FG=$(NOTIF_HEX2G "$DCS_FROM")
	DCS_FB=$(NOTIF_HEX2B "$DCS_FROM")
	DCS_TR=$(NOTIF_HEX2R "$DCS_TO")
	DCS_TG=$(NOTIF_HEX2G "$DCS_TO")
	DCS_TB=$(NOTIF_HEX2B "$DCS_TO")
	DCS_I=0
	while [ "$DCS_I" -le "$DCS_STEPS" ]; do
		NOTIF_STYLE_RESET
		NOTIF_ST_DIM_COLOUR="$(NOTIF_RGB2HEX \
			"$(NOTIF_LERP_BYTE "$DCS_FR" "$DCS_TR" "$DCS_I" "$DCS_STEPS")" \
			"$(NOTIF_LERP_BYTE "$DCS_FG" "$DCS_TG" "$DCS_I" "$DCS_STEPS")" \
			"$(NOTIF_LERP_BYTE "$DCS_FB" "$DCS_TB" "$DCS_I" "$DCS_STEPS")")"
		NOTIF_ST_DIM_ALPHA=120
		NOTIF_WRITE_ST "$DCS_MSG"
		NOTIF_SLEEP 0.05
		DCS_I=$((DCS_I + 1))
	done
}

NOTIF_FADE_IN() {
	FI_STEPS="$1"
	FI_MSG="$2"
	FI_STYLE="${3:-}"
	FI_I=0
	while [ "$FI_I" -le "$FI_STEPS" ]; do
		NOTIF_STYLE_APPLY "$FI_STYLE"
		NOTIF_ST_FONT_ALPHA="$(NOTIF_LERP_BYTE 0 255 "$FI_I" "$FI_STEPS")"
		NOTIF_ST_BOX_ALPHA="$(NOTIF_LERP_BYTE 0 "$NOTIF_ST_BOX_ALPHA" "$FI_I" "$FI_STEPS")"
		NOTIF_ST_BORDER_ALPHA="$(NOTIF_LERP_BYTE 0 "$NOTIF_ST_BORDER_ALPHA" "$FI_I" "$FI_STEPS")"
		NOTIF_WRITE_ST "$FI_MSG"
		NOTIF_SLEEP 0.04
		FI_I=$((FI_I + 1))
	done
}

NOTIF_FADE_OUT() {
	FO_STEPS="$1"
	FO_MSG="$2"
	FO_STYLE="${3:-}"
	FO_I=0
	while [ "$FO_I" -le "$FO_STEPS" ]; do
		NOTIF_STYLE_APPLY "$FO_STYLE"
		NOTIF_ST_FONT_ALPHA="$(NOTIF_LERP_BYTE 255 0 "$FO_I" "$FO_STEPS")"
		NOTIF_ST_BOX_ALPHA="$(NOTIF_LERP_BYTE "$NOTIF_ST_BOX_ALPHA" 0 "$FO_I" "$FO_STEPS")"
		NOTIF_ST_BORDER_ALPHA="$(NOTIF_LERP_BYTE "$NOTIF_ST_BORDER_ALPHA" 0 "$FO_I" "$FO_STEPS")"
		NOTIF_WRITE_ST "$FO_MSG"
		NOTIF_SLEEP 0.04
		FO_I=$((FO_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_CROSSFADE() {
	NOTIF_FADE_OUT "$1" "$2" "${4:-}"
	NOTIF_FADE_IN "$1" "$3" "${4:-}"
}

NOTIF_COLOUR_SHIFT() {
	CS_FROM="$1"
	CS_TO="$2"
	CS_STEPS="$3"
	CS_MSG="$4"
	CS_FR=$(NOTIF_HEX2R "$CS_FROM")
	CS_FG=$(NOTIF_HEX2G "$CS_FROM")
	CS_FB=$(NOTIF_HEX2B "$CS_FROM")
	CS_TR=$(NOTIF_HEX2R "$CS_TO")
	CS_TG=$(NOTIF_HEX2G "$CS_TO")
	CS_TB=$(NOTIF_HEX2B "$CS_TO")
	CS_I=0
	while [ "$CS_I" -le "$CS_STEPS" ]; do
		NOTIF_STYLE_RESET
		NOTIF_ST_BOX_COLOUR="$(NOTIF_RGB2HEX \
			"$(NOTIF_LERP_BYTE "$CS_FR" "$CS_TR" "$CS_I" "$CS_STEPS")" \
			"$(NOTIF_LERP_BYTE "$CS_FG" "$CS_TG" "$CS_I" "$CS_STEPS")" \
			"$(NOTIF_LERP_BYTE "$CS_FB" "$CS_TB" "$CS_I" "$CS_STEPS")")"
		NOTIF_ST_FONT_ALIGN=2
		NOTIF_WRITE_ST "$CS_MSG"
		NOTIF_SLEEP 0.05
		CS_I=$((CS_I + 1))
	done
}

NOTIF_COUNTDOWN() {
	CD_SECS="$1"
	CD_FMT="$2"
	CD_STYLE="${3:-}"
	while [ "$CD_SECS" -ge 0 ]; do
		NOTIF_STYLE_APPLY "$CD_STYLE"
		NOTIF_WRITE_ST "$(awk -v f="$CD_FMT" -v v="$CD_SECS" 'BEGIN { printf f, v }')"
		[ "$CD_SECS" -eq 0 ] && break
		NOTIF_SLEEP 1
		CD_SECS=$((CD_SECS - 1))
	done
	NOTIF_CLEAR
}

NOTIF_COUNTUP() {
	CU_TOTAL="$1"
	CU_FMT="$2"
	CU_STYLE="${3:-}"
	CU_I=0
	while [ "$CU_I" -le "$CU_TOTAL" ]; do
		NOTIF_STYLE_APPLY "$CU_STYLE"
		NOTIF_WRITE_ST "$(awk -v f="$CU_FMT" -v v="$CU_I" 'BEGIN { printf f, v }')"
		[ "$CU_I" -eq "$CU_TOTAL" ] && break
		NOTIF_SLEEP 1
		CU_I=$((CU_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_PROGRESS() {
	NP_MIN="$1"
	NP_MAX="$2"
	NP_VAL="$3"
	NP_LBL="$4"
	NP_STYLE="${5:-}"
	NP_BAR="$(NOTIF_STR_BAR "$NP_MIN" "$NP_MAX" "$NP_VAL" 20)"
	NP_PCT="$(awk "BEGIN { printf \"%d\", int(($NP_VAL-$NP_MIN)*100/($NP_MAX-$NP_MIN)+0.5) }")"
	NOTIF_STYLE_APPLY "$NP_STYLE"
	NOTIF_WRITE_ST "$NP_LBL" "$NP_BAR $NP_PCT%"
}

NOTIF_PROGRESS_LOOP() {
	NPL_MIN="$1"
	NPL_MAX="$2"
	NPL_STEP="$3"
	NPL_DELAY="$4"
	NPL_LBL="$5"
	NPL_STYLE="${6:-}"
	NPL_VAL="$NPL_MIN"
	NPL_DS="$(awk "BEGIN { printf \"%.3f\", $NPL_DELAY/1000 }")"
	while [ "$NPL_VAL" -le "$NPL_MAX" ]; do
		NOTIF_PROGRESS "$NPL_MIN" "$NPL_MAX" "$NPL_VAL" "$NPL_LBL" "$NPL_STYLE"
		NPL_VAL=$((NPL_VAL + NPL_STEP))
		NOTIF_SLEEP "$NPL_DS"
	done
	NOTIF_CLEAR
}

NOTIF_SPINNER() {
	SP_SECS="$1"
	SP_MSG="$2"
	SP_STYLE="${3:-}"
	SP_FRAMES="/ - \\ |"
	SP_END="$(awk "BEGIN { printf \"%d\", $(date +%s) + $SP_SECS }")"
	while [ "$(date +%s)" -lt "$SP_END" ]; do
		for SP_F in $SP_FRAMES; do
			NOTIF_STYLE_APPLY "$SP_STYLE"
			NOTIF_WRITE_ST "$SP_F  $SP_MSG"
			NOTIF_SLEEP 0.1
			[ "$(date +%s)" -ge "$SP_END" ] && break
		done
	done
	NOTIF_CLEAR
}

NOTIF_TYPEWRITER() {
	TW_DELAY="$1"
	TW_MSG="$2"
	TW_STYLE="${3:-}"
	TW_LEN="${#TW_MSG}"
	TW_I=1
	while [ "$TW_I" -le "$TW_LEN" ]; do
		NOTIF_STYLE_APPLY "$TW_STYLE"
		NOTIF_WRITE_ST "$(printf '%s' "$TW_MSG" | cut -c1-"$TW_I")"
		NOTIF_SLEEP "$TW_DELAY"
		TW_I=$((TW_I + 1))
	done
}

NOTIF_WATCH_FILE() {
	WF_FILE="$1"
	WF_FMT="$2"
	WF_INTERVAL="${3:-1}"
	WF_STYLE="${4:-}"
	while [ -f "$WF_FILE" ]; do
		NOTIF_STYLE_APPLY "$WF_STYLE"
		NOTIF_WRITE_ST "$(awk -v f="$WF_FMT" -v v="$(head -n1 "$WF_FILE" 2>/dev/null)" 'BEGIN { printf f, v }')"
		NOTIF_SLEEP "$WF_INTERVAL"
	done
	NOTIF_CLEAR
}

NOTIF_WATCH_CMD() {
	WC_CMD="$1"
	WC_FMT="$2"
	WC_INTERVAL="${3:-2}"
	WC_STYLE="${4:-}"
	while true; do
		NOTIF_STYLE_APPLY "$WC_STYLE"
		NOTIF_WRITE_ST "$(awk -v f="$WC_FMT" -v v="$(eval "$WC_CMD" 2>/dev/null | head -n1)" 'BEGIN { printf f, v }')"
		NOTIF_SLEEP "$WC_INTERVAL"
	done
}

NOTIF_RAINBOW() {
	RB_COUNT="$1"
	RB_MSG="$2"
	RB_COLOURS="FF0000 FF6600 FFCC00 00CC00 0066FF 6600CC FF00CC"
	RB_I=0
	while [ "$RB_I" -lt "$RB_COUNT" ]; do
		for RB_COL in $RB_COLOURS; do
			NOTIF_STYLE_RESET
			NOTIF_ST_FONT_COLOUR="FFFFFF"
			NOTIF_ST_BOX_COLOUR="111111"
			NOTIF_ST_BORDER_COLOUR="$RB_COL"
			NOTIF_ST_BORDER_ALPHA=255
			NOTIF_ST_FONT_ALIGN=2
			NOTIF_WRITE_ST "$RB_MSG"
			NOTIF_SLEEP 0.12
		done
		RB_I=$((RB_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_POLICE() {
	PL_COUNT="$1"
	PL_MSG="$2"
	PL_I=0
	while [ "$PL_I" -lt "$PL_COUNT" ]; do
		NOTIF_STYLE_APPLY "error"
		NOTIF_ST_BOX_COLOUR="220000"
		NOTIF_ST_BORDER_COLOUR="FF2222"
		NOTIF_ST_DIM_COLOUR="220000"
		NOTIF_ST_DIM_ALPHA=140
		NOTIF_WRITE_ST "$PL_MSG"
		NOTIF_SLEEP 0.18
		NOTIF_STYLE_APPLY "info"
		NOTIF_ST_BOX_COLOUR="000022"
		NOTIF_ST_BORDER_COLOUR="2222FF"
		NOTIF_ST_DIM_COLOUR="000022"
		NOTIF_ST_DIM_ALPHA=140
		NOTIF_WRITE_ST "$PL_MSG"
		NOTIF_SLEEP 0.18
		PL_I=$((PL_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_GLITCH() {
	GL_COUNT="$1"
	GL_MSG="$2"
	GL_I=0
	while [ "$GL_I" -lt "$GL_COUNT" ]; do
		NOTIF_STYLE_RESET
		NOTIF_ST_POSITION="$(awk 'BEGIN { srand(); print int(rand()*9) }')"
		NOTIF_ST_FONT_ALPHA="$(awk 'BEGIN { srand(); print int(rand()*156)+100 }')"
		NOTIF_ST_BOX_COLOUR="001100"
		NOTIF_ST_BORDER_COLOUR="00FF44"
		NOTIF_ST_BORDER_ALPHA=255
		NOTIF_ST_FONT_ALIGN=2
		NOTIF_WRITE_ST "$GL_MSG"
		NOTIF_SLEEP 0.07
		GL_I=$((GL_I + 1))
	done
	NOTIF_CLEAR
}

NOTIF_SLIDE_IN() {
	SL_FROM="$1"
	SL_TO="$2"
	SL_STEPS="$3"
	SL_MSG="$4"
	SL_STYLE="${5:-}"
	SL_I=0
	while [ "$SL_I" -le "$SL_STEPS" ]; do
		NOTIF_STYLE_APPLY "$SL_STYLE"
		NOTIF_ST_POSITION="$(awk "BEGIN { printf \"%d\", int($SL_FROM+($SL_TO-$SL_FROM)*$SL_I/$SL_STEPS+0.5) }")"
		NOTIF_WRITE_ST "$SL_MSG"
		NOTIF_SLEEP 0.06
		SL_I=$((SL_I + 1))
	done
}

NOTIF_BOUNCE() {
	BN_COUNT="$1"
	BN_A="$2"
	BN_B="$3"
	BN_MSG="$4"
	BN_STYLE="${5:-}"
	BN_I=0
	while [ "$BN_I" -lt "$BN_COUNT" ]; do
		NOTIF_SLIDE_IN "$BN_A" "$BN_B" 6 "$BN_MSG" "$BN_STYLE"
		NOTIF_SLIDE_IN "$BN_B" "$BN_A" 6 "$BN_MSG" "$BN_STYLE"
		BN_I=$((BN_I + 1))
	done
}

NOTIF_STR_BAR() {
	awk -v mn="$1" -v mx="$2" -v v="$3" -v w="$4" 'BEGIN {
        if (mx == mn) { pct = 1 } else { pct = (v-mn)/(mx-mn) }
        if (pct < 0) pct = 0; if (pct > 1) pct = 1
        filled = int(pct * w + 0.5); empty = w - filled
        bar = "["
        for (i = 0; i < filled; i++) bar = bar "#"
        for (i = 0; i < empty;  i++) bar = bar "."
        printf "%s]\n", bar
    }'
}

NOTIF_STR_DOTS() {
	STR_DOTS_CHAR="${2:-.}"
	awk -v n="$1" -v c="$STR_DOTS_CHAR" 'BEGIN { for(i=0;i<n;i++) printf "%s",c; print "" }'
}

NOTIF_STR_CENTRE() {
	awk -v w="$1" -v t="$2" 'BEGIN {
        l=length(t); pad=int((w-l)/2)
        for(i=0;i<pad;i++) printf " "
        printf "%s\n", t
    }'
}

NOTIF_STR_TRUNCATE() {
	ST_MAX="$1"
	ST_TEXT="$2"
	ST_SUF="${3:-...}"
	if [ "${#ST_TEXT}" -le "$ST_MAX" ]; then
		printf '%s\n' "$ST_TEXT"
	else
		ST_CUT=$((ST_MAX - ${#ST_SUF}))
		printf '%s%s\n' "$(printf '%s' "$ST_TEXT" | cut -c1-"$ST_CUT")" "$ST_SUF"
	fi
}

NOTIF_STR_WRAP() {
	printf '%s\n' "$2" | awk -v w="$1" '{
        n = split($0, words, " "); line = ""
        for (i = 1; i <= n; i++) {
            trial = (line == "") ? words[i] : line " " words[i]
            if (length(trial) > w && line != "") { print line; line = words[i] }
            else { line = trial }
        }
        if (line != "") print line
    }'
}

NOTIF_STR_REPEAT() {
	awk -v n="$1" -v s="$2" 'BEGIN { for(i=0;i<n;i++) printf "%s",s; print "" }'
}

NOTIF_STR_UPPER() {
	printf '%s\n' "$1" | tr '[:lower:]' '[:upper:]'
}

NOTIF_STR_LOWER() {
	printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

NOTIF_STR_TIMESTAMP() {
	date '+%Y-%m-%d %H:%M:%S'
}

NOTIF_STR_ELAPSED() {
	awk -v s="$1" -v n="$(date +%s)" 'BEGIN {
        d = n-s; if (d < 0) d = 0
        if      (d < 60)   printf "%ds\n",     d
        else if (d < 3600) printf "%dm %ds\n", int(d/60), d%60
        else               printf "%dh %dm\n", int(d/3600), int((d%3600)/60)
    }'
}

NOTIF_STR_FILESIZE() {
	awk -v b="$1" 'BEGIN {
        if      (b < 1024)       printf "%d B\n",    b
        else if (b < 1048576)    printf "%.1f KB\n", b/1024
        else if (b < 1073741824) printf "%.1f MB\n", b/1048576
        else                     printf "%.2f GB\n", b/1073741824
    }'
}

NOTIF_BUILD_POSITION="$NOTIF_DEF_POSITION"
NOTIF_BUILD_FONT_SIZE="$NOTIF_DEF_FONT_SIZE"
NOTIF_BUILD_FONT_ALIGN="$NOTIF_DEF_FONT_ALIGN"
NOTIF_BUILD_FONT_COLOUR="$NOTIF_DEF_FONT_COLOUR"
NOTIF_BUILD_FONT_ALPHA="$NOTIF_DEF_FONT_ALPHA"
NOTIF_BUILD_BOX_COLOUR="$NOTIF_DEF_BOX_COLOUR"
NOTIF_BUILD_BOX_ALPHA="$NOTIF_DEF_BOX_ALPHA"
NOTIF_BUILD_BORDER_COLOUR="$NOTIF_DEF_BORDER_COLOUR"
NOTIF_BUILD_BORDER_ALPHA="$NOTIF_DEF_BORDER_ALPHA"
NOTIF_BUILD_DIM_COLOUR="$NOTIF_DEF_DIM_COLOUR"
NOTIF_BUILD_DIM_ALPHA="$NOTIF_DEF_DIM_ALPHA"
NOTIF_BUILD_LINES=""
NOTIF_BUILD_LINE_COUNT=0

NOTIF_BUILD_RESET() {
	NOTIF_BUILD_POSITION="$NOTIF_DEF_POSITION"
	NOTIF_BUILD_FONT_SIZE="$NOTIF_DEF_FONT_SIZE"
	NOTIF_BUILD_FONT_ALIGN="$NOTIF_DEF_FONT_ALIGN"
	NOTIF_BUILD_FONT_COLOUR="$NOTIF_DEF_FONT_COLOUR"
	NOTIF_BUILD_FONT_ALPHA="$NOTIF_DEF_FONT_ALPHA"
	NOTIF_BUILD_BOX_COLOUR="$NOTIF_DEF_BOX_COLOUR"
	NOTIF_BUILD_BOX_ALPHA="$NOTIF_DEF_BOX_ALPHA"
	NOTIF_BUILD_BORDER_COLOUR="$NOTIF_DEF_BORDER_COLOUR"
	NOTIF_BUILD_BORDER_ALPHA="$NOTIF_DEF_BORDER_ALPHA"
	NOTIF_BUILD_DIM_COLOUR="$NOTIF_DEF_DIM_COLOUR"
	NOTIF_BUILD_DIM_ALPHA="$NOTIF_DEF_DIM_ALPHA"
	NOTIF_BUILD_LINES=""
	NOTIF_BUILD_LINE_COUNT=0
}

NOTIF_BUILD_START() {
	NOTIF_BUILD_RESET
}

NOTIF_BUILD_STYLE() {
	NOTIF_STYLE_APPLY "$1"
	NOTIF_BUILD_POSITION="$NOTIF_ST_POSITION"
	NOTIF_BUILD_FONT_SIZE="$NOTIF_ST_FONT_SIZE"
	NOTIF_BUILD_FONT_ALIGN="$NOTIF_ST_FONT_ALIGN"
	NOTIF_BUILD_FONT_COLOUR="$NOTIF_ST_FONT_COLOUR"
	NOTIF_BUILD_FONT_ALPHA="$NOTIF_ST_FONT_ALPHA"
	NOTIF_BUILD_BOX_COLOUR="$NOTIF_ST_BOX_COLOUR"
	NOTIF_BUILD_BOX_ALPHA="$NOTIF_ST_BOX_ALPHA"
	NOTIF_BUILD_BORDER_COLOUR="$NOTIF_ST_BORDER_COLOUR"
	NOTIF_BUILD_BORDER_ALPHA="$NOTIF_ST_BORDER_ALPHA"
	NOTIF_BUILD_DIM_COLOUR="$NOTIF_ST_DIM_COLOUR"
	NOTIF_BUILD_DIM_ALPHA="$NOTIF_ST_DIM_ALPHA"
}

NOTIF_BUILD_SET() {
	case "$1" in
		position) NOTIF_BUILD_POSITION="$2" ;;
		font_size) NOTIF_BUILD_FONT_SIZE="$2" ;;
		font_align) NOTIF_BUILD_FONT_ALIGN="$2" ;;
		font_colour) NOTIF_BUILD_FONT_COLOUR="$2" ;;
		font_alpha) NOTIF_BUILD_FONT_ALPHA="$2" ;;
		box_colour) NOTIF_BUILD_BOX_COLOUR="$2" ;;
		box_alpha) NOTIF_BUILD_BOX_ALPHA="$2" ;;
		border_colour) NOTIF_BUILD_BORDER_COLOUR="$2" ;;
		border_alpha) NOTIF_BUILD_BORDER_ALPHA="$2" ;;
		dim_colour) NOTIF_BUILD_DIM_COLOUR="$2" ;;
		dim_alpha) NOTIF_BUILD_DIM_ALPHA="$2" ;;
		*) printf 'NOTIF_BUILD_SET: unknown key "%s"\n' "$1" >&2 ;;
	esac
}

NOTIF_BUILD_ADD() {
	if [ "$NOTIF_BUILD_LINE_COUNT" -eq 0 ]; then
		NOTIF_BUILD_LINES="$1"
	else
		NOTIF_BUILD_LINES="$(printf '%s\n%s' "$NOTIF_BUILD_LINES" "$1")"
	fi

	NOTIF_BUILD_LINE_COUNT=$((NOTIF_BUILD_LINE_COUNT + 1))
}

NOTIF_BUILD_SEND() {
	if [ "$NOTIF_BUILD_LINE_COUNT" -eq 0 ]; then
		printf 'NOTIF_BUILD_SEND: no lines added\n' >&2
		return 1
	fi

	{
		printf 'position      = %s\n' "$NOTIF_BUILD_POSITION"
		printf 'font_size     = %s\n' "$NOTIF_BUILD_FONT_SIZE"
		printf 'font_align    = %s\n' "$NOTIF_BUILD_FONT_ALIGN"
		printf 'font_colour   = %s\n' "$NOTIF_BUILD_FONT_COLOUR"
		printf 'font_alpha    = %s\n' "$NOTIF_BUILD_FONT_ALPHA"
		printf 'box_colour    = %s\n' "$NOTIF_BUILD_BOX_COLOUR"
		printf 'box_alpha     = %s\n' "$NOTIF_BUILD_BOX_ALPHA"
		printf 'border_colour = %s\n' "$NOTIF_BUILD_BORDER_COLOUR"
		printf 'border_alpha  = %s\n' "$NOTIF_BUILD_BORDER_ALPHA"
		printf 'dim_colour    = %s\n' "$NOTIF_BUILD_DIM_COLOUR"
		printf 'dim_alpha     = %s\n' "$NOTIF_BUILD_DIM_ALPHA"
		printf '%s\n' '-'
		printf '%s\n' "$NOTIF_BUILD_LINES"
	} >"$NOTIF_PATH"
}

NOTIF_BUILD_PREVIEW() {
	printf 'position      = %s\n' "$NOTIF_BUILD_POSITION"
	printf 'font_size     = %s\n' "$NOTIF_BUILD_FONT_SIZE"
	printf 'font_align    = %s\n' "$NOTIF_BUILD_FONT_ALIGN"
	printf 'font_colour   = %s\n' "$NOTIF_BUILD_FONT_COLOUR"
	printf 'font_alpha    = %s\n' "$NOTIF_BUILD_FONT_ALPHA"
	printf 'box_colour    = %s\n' "$NOTIF_BUILD_BOX_COLOUR"
	printf 'box_alpha     = %s\n' "$NOTIF_BUILD_BOX_ALPHA"
	printf 'border_colour = %s\n' "$NOTIF_BUILD_BORDER_COLOUR"
	printf 'border_alpha  = %s\n' "$NOTIF_BUILD_BORDER_ALPHA"
	printf 'dim_colour    = %s\n' "$NOTIF_BUILD_DIM_COLOUR"
	printf 'dim_alpha     = %s\n' "$NOTIF_BUILD_DIM_ALPHA"
	printf '%s\n' '-'
	printf '%s\n' "$NOTIF_BUILD_LINES"
}

NOTIF_BATTERY() {
	NB_STYLE="${1:-}"
	NB_CAP="$(cat /sys/class/power_supply/*/capacity 2>/dev/null | head -n1)"
	NB_STATUS="$(cat /sys/class/power_supply/*/status 2>/dev/null | head -n1)"

	if [ -z "$NB_CAP" ]; then
		NOTIF_STYLE_APPLY "warn${NB_STYLE:+:$NB_STYLE}"
		NOTIF_WRITE_ST "Battery info unavailable"
		return
	fi

	if [ "$NB_CAP" -le 15 ]; then
		NOTIF_STYLE_APPLY "error${NB_STYLE:+:$NB_STYLE}"
	elif [ "$NB_CAP" -le 30 ]; then
		NOTIF_STYLE_APPLY "warn${NB_STYLE:+:$NB_STYLE}"
	else
		NOTIF_STYLE_APPLY "info${NB_STYLE:+:$NB_STYLE}"
	fi

	NOTIF_WRITE_ST "Battery: ${NB_CAP}%  ${NB_STATUS}"
}

NOTIF_UPTIME() {
	NU_STYLE="${1:-}"
	NU_UP="$(uptime 2>/dev/null | sed 's/.*up \([^,]*\).*/\1/' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
	NOTIF_STYLE_APPLY "$NU_STYLE"
	NOTIF_WRITE_ST "Uptime: ${NU_UP}"
}

NOTIF_IP() {
	NI_STYLE="${1:-}"
	NI_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')"

	if [ -z "$NI_IP" ]; then
		NI_IP="$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -n1)"
	fi

	[ -z "$NI_IP" ] && NI_IP="No network"
	NOTIF_STYLE_APPLY "$NI_STYLE"
	NOTIF_WRITE_ST "IP: ${NI_IP}"
}

NOTIF_STORAGE() {
	NST_PATH="${1:-/}"
	NST_STYLE="${2:-}"
	NST_INFO="$(df -h "$NST_PATH" 2>/dev/null | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')"
	[ -z "$NST_INFO" ] && NST_INFO="Unavailable"
	NOTIF_STYLE_APPLY "$NST_STYLE"
	NOTIF_WRITE_ST "Storage $NST_PATH:" "$NST_INFO"
}

NOTIF_DATE_TIME() {
	NDT_STYLE="${1:-}"
	NOTIF_BUILD_START
	NOTIF_BUILD_STYLE "$NDT_STYLE"
	NOTIF_BUILD_SET font_align 2
	NOTIF_BUILD_ADD "$(date '+%A, %d %B %Y')"
	NOTIF_BUILD_ADD "$(date '+%H:%M:%S')"
	NOTIF_BUILD_SEND
}

NOTIF_CONFIRM() {
	NC_STYLE="${2:-}"
	NOTIF_STYLE_APPLY "$NC_STYLE"
	NOTIF_ST_DIM_ALPHA=140
	NOTIF_ST_FONT_ALIGN=2
	NOTIF_WRITE_ST "$1" "" "Press any button to continue"
}

NOTIF_HELP() {
	NOTIF_BUILD_START
	NOTIF_BUILD_SET font_size 16
	NOTIF_BUILD_SET font_align 3
	NOTIF_BUILD_SET position 4
	NOTIF_BUILD_SET dim_alpha 160
	NOTIF_BUILD_ADD "notif.sh -- function reference"
	NOTIF_BUILD_ADD "------------------------------"
	NOTIF_BUILD_ADD "NOTIF_SHOW <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_SHOW_AT <pos> <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_SHOW_TIMED <s> <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_MULTILINE <line> ..."
	NOTIF_BUILD_ADD "NOTIF_INFO/WARN/ERROR/SUCCESS <msg>"
	NOTIF_BUILD_ADD "NOTIF_TOAST/BANNER <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_FLASH <n> <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_BORDER_FLASH <n> <col> <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_COUNTDOWN <s> <fmt> [style]"
	NOTIF_BUILD_ADD "NOTIF_PROGRESS <mn> <mx> <v> <lbl> [style]"
	NOTIF_BUILD_ADD "NOTIF_SPINNER <s> <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_TYPEWRITER <delay> <msg> [style]"
	NOTIF_BUILD_ADD "NOTIF_RAINBOW/POLICE/GLITCH <n> <msg>"
	NOTIF_BUILD_ADD "NOTIF_BUILD_START/STYLE/SET/ADD/SEND"
	NOTIF_BUILD_ADD "NOTIF_STR_BAR/WRAP/TRUNCATE/..."
	NOTIF_BUILD_ADD "NOTIF_BATTERY/UPTIME/IP/STORAGE [style]"
	NOTIF_BUILD_ADD "NOTIF_CLEAR"
	NOTIF_BUILD_SEND
}
