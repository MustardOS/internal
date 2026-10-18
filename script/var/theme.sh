#!/bin/sh

[ -n "${MUOS_THEME_LOADED-}" ] && return 0
MUOS_THEME_LOADED=1
[ -n "${MUOS_DISPLAY_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/display.sh"

# Degrees a raw screen capture is turned to be upright, for panels mounted sideways
SCREEN_CAPTURE_ROTATION() {
	case "$(GET_VAR "device" "board/name")" in
		mgx*) printf '270' ;;
		rg-vita* | rg28xx-h | rk-pixel-2) printf '90' ;;
		*) printf '0' ;;
	esac
}

DEVICE_THEME_FIX() {
	ROLE="$1"
	IMAGE="$2"

	case "$(GET_VAR "device" "board/name")" in
		rg28xx-h)
			convert "$IMAGE" -rotate 270 "$IMAGE"
			printf "Rotated '%s' image: %s\n" "$ROLE" "$IMAGE"
			;;
	esac
}

THEME_PNG_IMAGE() {
	ROLE="$1"
	SRC="$2"
	OUT="$3"

	BACKGROUND_COLOUR="000000"
	BACKGROUND_GRADIENT_COLOUR="000000"
	PNG_RECOLOUR="FFFFFF"
	PNG_RECOLOUR_ALPHA=0

	NORMALISE_HEX() {
		VAL="${1#\#}"

		case "$VAL" in
			[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
				printf "%s" "$VAL"
				return 0
				;;
		esac

		return 1
	}

	CLAMP_ALPHA() {
		VAL="$1"

		case "$VAL" in
			'' | *[!0-9]*) VAL=0 ;;
		esac

		[ "$VAL" -lt 0 ] && VAL=0
		[ "$VAL" -gt 255 ] && VAL=255

		printf "%s" "$VAL"
	}

	JSONPATH="$THEME_DIR/${ROLE}.json"

	if [ -e "$THEME_DIR/active.txt" ]; then
		read -r THEME_ALTERNATE <"$THEME_DIR/active.txt"
		printf "Theme Alternate: %s\n" "$THEME_ALTERNATE"
		ALT_JSON="$THEME_DIR/alternate/${THEME_ALTERNATE}_${ROLE}.json"
		[ -e "$ALT_JSON" ] && JSONPATH="$ALT_JSON"
	fi

	if [ -e "$JSONPATH" ]; then
		printf "Found '%s' JSON: %s\n" "$ROLE" "$JSONPATH"

		# Single jq invocation pulling all four values, tab-separated
		JQ_OUT=$(jq -r '[.background_colour, .background_gradient_colour, .png_recolour, .png_recolour_alpha] | map(. // "") | @tsv' "$JSONPATH")
		IFS='	' read -r JQ_BG JQ_BGG JQ_PR JQ_PRA <<EOF
$JQ_OUT
EOF

		if [ -n "$JQ_BG" ] && HEX=$(NORMALISE_HEX "$JQ_BG"); then
			BACKGROUND_COLOUR="$HEX"
		fi

		if [ -n "$JQ_BGG" ] && HEX=$(NORMALISE_HEX "$JQ_BGG"); then
			BACKGROUND_GRADIENT_COLOUR="$HEX"
		else
			BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"
		fi

		if [ -n "$JQ_PR" ] && HEX=$(NORMALISE_HEX "$JQ_PR"); then
			PNG_RECOLOUR="$HEX"
		fi

		if [ -n "$JQ_PRA" ]; then
			RAW_ALPHA=$(CLAMP_ALPHA "$JQ_PRA")
			PNG_RECOLOUR_ALPHA=$((RAW_ALPHA * 100 / 255))
		fi
	else
		printf "No '%s' JSON found... using defaults!\n" "$ROLE"
	fi

	[ -z "$BACKGROUND_GRADIENT_COLOUR" ] && BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"

	if [ "$PNG_RECOLOUR_ALPHA" -le 0 ]; then
		PNG_RECOLOUR=""
		PNG_RECOLOUR_ALPHA=0
	fi

	printf "Creating '%s' image:\n" "$ROLE"
	printf "SRC: %s\n" "$SRC"
	printf "OUT: %s\n" "$OUT"
	printf "BACKGROUND_COLOUR: %s\n" "$BACKGROUND_COLOUR"
	printf "BACKGROUND_GRADIENT_COLOUR: %s\n" "$BACKGROUND_GRADIENT_COLOUR"
	printf "PNG_RECOLOUR: %s\n" "$PNG_RECOLOUR"
	printf "PNG_RECOLOUR_ALPHA: %s\n" "$PNG_RECOLOUR_ALPHA"

	TMP_BG="/tmp/${ROLE}_bg_$$.png"
	TMP_FG="/tmp/${ROLE}_fg_$$.png"
	TMP_OUT="/tmp/${ROLE}_out_$$.png"

	rm -f "$TMP_BG" "$TMP_FG" "$TMP_OUT"

	if [ "$BACKGROUND_COLOUR" = "$BACKGROUND_GRADIENT_COLOUR" ]; then
		magick -size "${DEVICE_W}x${DEVICE_H}" xc:"#${BACKGROUND_COLOUR}" "$TMP_BG"
	else
		magick -size 1x"${DEVICE_H}" gradient:"#${BACKGROUND_COLOUR}-#${BACKGROUND_GRADIENT_COLOUR}" -resize "${DEVICE_W}x${DEVICE_H}!" "$TMP_BG"
	fi

	if [ "$PNG_RECOLOUR_ALPHA" -gt 0 ]; then
		magick "$SRC" -fill "#${PNG_RECOLOUR}" -colorize "$PNG_RECOLOUR_ALPHA" "$TMP_FG"
	else
		cp -f "$SRC" "$TMP_FG"
	fi

	magick "$TMP_FG" "$TMP_BG" -compose Dst_Over -composite -alpha off BMP3:"$TMP_OUT"
	case "$OUT" in
		*.bmp | *.BMP) magick "$TMP_OUT" BMP3:"$OUT" ;;
		*) mv -f "$TMP_OUT" "$OUT" ;;
	esac

	rm -f "$TMP_BG" "$TMP_FG" "$TMP_OUT"
}

RESOLVE_ROLE_IMAGE() {
	ROLE="$1"
	OUT="$2"

	for BASE in "$THEME_DIR/$RES_DIR/image/$ROLE" "$THEME_DIR/image/$ROLE"; do
		printf "Checking path: %s\n" "$BASE.png"
		if [ -f "$BASE.png" ]; then
			printf "Found %s PNG: %s\n" "$ROLE" "$BASE.png"
			THEME_PNG_IMAGE "$ROLE" "$BASE.png" "$OUT"
			return 0
		fi

		printf "Checking path: %s\n" "$BASE.bmp"
		if [ -f "$BASE.bmp" ]; then
			printf "Found %s BMP: %s\n" "$ROLE" "$BASE.bmp"
			cp -f "$BASE.bmp" "$OUT"
			return 0
		fi
	done

	return 1
}

UPDATE_IMAGE_ROLE() {
	ROLE="$1" # bootlogo, charge, etc
	DEST="$2" # relative to boot mount

	OUT="$BOOT_MOUNT/$DEST"
	DIR=$(dirname "$OUT")

	mkdir -p "$DIR"

	if ! RESOLVE_ROLE_IMAGE "$ROLE" "$OUT"; then
		printf "No theme '%s' image found\n" "$ROLE"
		return 1
	fi

	DEVICE_THEME_FIX "$ROLE" "$OUT"
	return 0
}

APPLY_LOGO_IMAGE() {
	SRC="$1"
	OUT="$2"
	MODE="${3:-fullscreen}"

	mkdir -p "$(dirname "$OUT")"

	TMP_OUT="/tmp/logo_out_$$.png"
	rm -f "$TMP_OUT"

	case "$MODE" in
		# Cover the screen and trim whatever falls outside it
		crop)
			magick "${SRC}[0]" -resize "${DEVICE_W}x${DEVICE_H}^" -background black -gravity center \
				-extent "${DEVICE_W}x${DEVICE_H}" -alpha off "$TMP_OUT"
			;;
		# Fill the screen exactly, aspect ratio be damned
		stretch)
			magick "${SRC}[0]" -resize "${DEVICE_W}x${DEVICE_H}!" -alpha off "$TMP_OUT"
			;;
		# Left at its own size, centred, and trimmed if it overhangs
		original)
			magick "${SRC}[0]" -background black -gravity center \
				-extent "${DEVICE_W}x${DEVICE_H}" -alpha off "$TMP_OUT"
			;;
		# As large as it will go while keeping its shape
		*)
			magick "${SRC}[0]" -resize "${DEVICE_W}x${DEVICE_H}" -background black -gravity center \
				-extent "${DEVICE_W}x${DEVICE_H}" -alpha off "$TMP_OUT"
			;;
	esac

	magick "$TMP_OUT" BMP3:"$OUT"
	rm -f "$TMP_OUT"

	DEVICE_THEME_FIX "bootlogo" "$OUT"
}

UPDATE_BOOTLOGO() {
	rm -f "/tmp/btl_go"

	BOOT_MOUNT=$(GET_VAR "device" "storage/boot/mount")
	[ -n "$BOOT_MOUNT" ] || return 1

	DEVICE_W=$(GET_VAR "device" "screen/internal/width")
	DEVICE_H=$(GET_VAR "device" "screen/internal/height")

	[ -n "$DEVICE_W" ] || DEVICE_W=$(GET_VAR "device" "screen/width")
	[ -n "$DEVICE_H" ] || DEVICE_H=$(GET_VAR "device" "screen/height")
	[ -n "$DEVICE_W" ] || return 1
	[ -n "$DEVICE_H" ] || return 1

	ACTIVE=$(GET_VAR "config" "theme/active")
	THEME_DIR="$MUOS_STORE_DIR/theme/$ACTIVE"
	RES_DIR="${DEVICE_W}x${DEVICE_H}"

	DEFAULT_LOGO="$MUOS_SHARE_DIR/bootlogo/${DEVICE_W}x${DEVICE_H}/bootlogo.bmp"

	# Some devices keep their boot logo outside the boot partition, so the device
	# gets a chance to copy it to wherever its bootloader reads it from
	if UPDATE_IMAGE_ROLE "bootlogo" "bootlogo.bmp"; then
		RUN_DEVICE_SCRIPT bootlogo.sh apply "$BOOT_MOUNT/bootlogo.bmp"
	elif [ -f "$DEFAULT_LOGO" ]; then
		cp -f "$DEFAULT_LOGO" "$BOOT_MOUNT/bootlogo.bmp"
		DEVICE_THEME_FIX "bootlogo" "$BOOT_MOUNT/bootlogo.bmp"
		RUN_DEVICE_SCRIPT bootlogo.sh apply "$BOOT_MOUNT/bootlogo.bmp"
	else
		RUN_DEVICE_SCRIPT bootlogo.sh restore
	fi

	if ! UPDATE_IMAGE_ROLE "charge" "bat/battery_charge.bmp"; then
		mkdir -p "$BOOT_MOUNT/bat"
		cp -f "$BOOT_MOUNT/bootlogo.bmp" "$BOOT_MOUNT/bat/battery_charge.bmp"
	fi

	return 0
}

SHOW_SPLASH() {
	ROLE="${1:-load}"
	READY_PATH="${2:-}"
	EXEC_MODE="${3:-0}"

	SPLASH_BIN="/opt/muos/frontend/musplash"
	[ -x "$SPLASH_BIN" ] || return 1

	case "$ROLE" in
		bootlogo | shutdown | reboot | reset | load) ;;
		clear) "$SPLASH_BIN" -c && return 0 ;;
		*) return 1 ;;
	esac

	DEVICE_W=$(GET_VAR "device" "screen/internal/width")
	DEVICE_H=$(GET_VAR "device" "screen/internal/height")

	[ -n "$DEVICE_W" ] || DEVICE_W=$(GET_VAR "device" "screen/width")
	[ -n "$DEVICE_H" ] || DEVICE_H=$(GET_VAR "device" "screen/height")
	[ -n "$DEVICE_W" ] || return 1
	[ -n "$DEVICE_H" ] || return 1

	ACTIVE=$(GET_VAR "config" "theme/active")
	THEME_DIR="$MUOS_STORE_DIR/theme/$ACTIVE"
	RES_DIR="${DEVICE_W}x${DEVICE_H}"

	# TODO: Add splash scale to advanced options
	SCALE=$(GET_VAR "config" "settings/advanced/splash_scale")
	case "$SCALE" in
		0 | 1 | 2 | 3) ;;
		*) SCALE=0 ;;
	esac

	ROTATE=$(GET_VAR "device" "screen/splash_rotate")
	case "$ROTATE" in
		0 | 90 | 180 | 270) ;;
		"")
			case "$(GET_VAR "device" "board/name")" in
				rg28xx-h | rg-vita-pro) ROTATE=270 ;;
				*) ROTATE=0 ;;
			esac
			;;
		*) ROTATE=0 ;;
	esac

	BACKGROUND_COLOUR="000000"
	BACKGROUND_GRADIENT_COLOUR="000000"
	PNG_RECOLOUR="FFFFFF"
	PNG_RECOLOUR_ALPHA=0

	NORMALISE_HEX() {
		VAL="${1#\#}"

		case "$VAL" in
			[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
				printf "%s" "$VAL"
				return 0
				;;
		esac

		return 1
	}

	CLAMP_ALPHA() {
		VAL="$1"

		case "$VAL" in
			'' | *[!0-9]*) VAL=0 ;;
		esac

		[ "$VAL" -lt 0 ] && VAL=0
		[ "$VAL" -gt 255 ] && VAL=255

		printf "%s" "$VAL"
	}

	JSONPATH="$THEME_DIR/${ROLE}.json"

	if [ -e "$THEME_DIR/active.txt" ]; then
		read -r THEME_ALTERNATE <"$THEME_DIR/active.txt"
		ALT_JSON="$THEME_DIR/alternate/${THEME_ALTERNATE}_${ROLE}.json"
		[ -e "$ALT_JSON" ] && JSONPATH="$ALT_JSON"
	fi

	if [ -e "$JSONPATH" ]; then
		# Single jq invocation pulling all four values, tab-separated
		JQ_OUT=$(jq -r '[.background_colour, .background_gradient_colour, .png_recolour, .png_recolour_alpha] | map(. // "") | @tsv' "$JSONPATH")
		IFS='	' read -r JQ_BG JQ_BGG JQ_PR JQ_PRA <<EOF
$JQ_OUT
EOF

		if [ -n "$JQ_BG" ] && HEX=$(NORMALISE_HEX "$JQ_BG"); then
			BACKGROUND_COLOUR="$HEX"
		fi

		if [ -n "$JQ_BGG" ] && HEX=$(NORMALISE_HEX "$JQ_BGG"); then
			BACKGROUND_GRADIENT_COLOUR="$HEX"
		else
			BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"
		fi

		if [ -n "$JQ_PR" ] && HEX=$(NORMALISE_HEX "$JQ_PR"); then
			PNG_RECOLOUR="$HEX"
		fi

		if [ -n "$JQ_PRA" ]; then
			RAW_ALPHA=$(CLAMP_ALPHA "$JQ_PRA")
			PNG_RECOLOUR_ALPHA=$((RAW_ALPHA * 100 / 255))
		fi
	fi

	[ -z "$BACKGROUND_GRADIENT_COLOUR" ] && BACKGROUND_GRADIENT_COLOUR="$BACKGROUND_COLOUR"

	set -- -r "$ROTATE" -s "$SCALE" -g "${BACKGROUND_COLOUR}:${BACKGROUND_GRADIENT_COLOUR}"
	[ -n "$READY_PATH" ] && set -- "$@" -n "$READY_PATH"

	# Always leave a trace, and not as a .log since boot wipes those before it can be read
	set -- "$@" -l "$MUOS_LOG_DIR/musplash.trace"

	if [ "$PNG_RECOLOUR_ALPHA" -gt 0 ]; then
		set -- "$@" -t "$PNG_RECOLOUR" -a "$PNG_RECOLOUR_ALPHA"
	fi

	FBCON_DISABLE

	CURR_LANG="$(GET_VAR "config" "settings/general/language")"

	for SRC in \
		"$THEME_DIR/$RES_DIR/image/$CURR_LANG/$ROLE.png" \
		"$THEME_DIR/$RES_DIR/image/$ROLE.png" \
		"$THEME_DIR/image/$CURR_LANG/$ROLE.png" \
		"$THEME_DIR/image/$ROLE.png" \
		"$MUOS_SHARE_DIR/theme/MustardOS/$RES_DIR/image/$CURR_LANG/$ROLE.png" \
		"$MUOS_SHARE_DIR/theme/MustardOS/$RES_DIR/image/$ROLE.png" \
		"$MUOS_SHARE_DIR/theme/MustardOS/image/$CURR_LANG/$ROLE.png" \
		"$MUOS_SHARE_DIR/theme/MustardOS/image/$ROLE.png" \
		"$MUOS_SHARE_DIR/media/splash/$RES_DIR/$CURR_LANG/$ROLE.png" \
		"$MUOS_SHARE_DIR/media/splash/$RES_DIR/$ROLE.png" \
		"$MUOS_SHARE_DIR/media/splash/$ROLE.png"; do
		if [ -f "$SRC" ]; then
			[ "$EXEC_MODE" -eq 1 ] 2>/dev/null && exec "$SPLASH_BIN" -i "$SRC" -w "$@"
			"$SPLASH_BIN" -i "$SRC" "$@"
			return $?
		fi
	done

	return 1
}
