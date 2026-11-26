#!/bin/sh

[ -n "${MUOS_EMULATOR_LOADED-}" ] && return 0
MUOS_EMULATOR_LOADED=1
[ -n "${MUOS_LOG_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/log.sh"

EMULATOR_STAMP="$MUOS_SHARE_DIR/emulator/installed.md5"

EMULATOR_VARIANT() {
	case "$(GET_VAR "device" "board/name")" in
		rg-vita*) printf 'vita' ;;
		rg*) printf 'rg' ;;
		gcs* | mgx* | tui*) printf 'tui' ;;
		rk*) printf 'rk' ;;
	esac
}

EMULATOR_SOURCES() {
	cat "$MUOS_SHARE_DIR"/emulator/*/*-"$1".md5 2>/dev/null
}

EMULATORS_CURRENT() {
	[ -n "$1" ] && [ -r "$EMULATOR_STAMP" ] && [ "$(cat "$EMULATOR_STAMP")" = "$(EMULATOR_SOURCES "$1")" ]
}

INSTALL_BIN() {
	SRC_BIN="$1"
	SRC_MD5="$2"
	TGT_BIN="$3"

	[ -e "$SRC_BIN" ] || return 0

	EXPECTED_MD5=$(cat "$SRC_MD5" 2>/dev/null) || return 0

	CURRENT_MD5=
	[ -f "$TGT_BIN" ] && {
		CURRENT_MD5=$(md5sum "$TGT_BIN" 2>/dev/null)
		CURRENT_MD5=${CURRENT_MD5%% *}
	}

	if [ "$CURRENT_MD5" != "$EXPECTED_MD5" ]; then
		TGT_TMP=$(mktemp "${TGT_BIN}.XXXXXX") || return 1
		if cp -f "$SRC_BIN" "$TGT_TMP" && chmod +x "$TGT_TMP" && mv -f "$TGT_TMP" "$TGT_BIN"; then
			:
		else
			rm -f "$TGT_TMP"
			return 1
		fi
	fi
}

# Install a binary packed inside a versioned tar.gz if its MD5 differs from the installed copy.
INSTALL_ARCHIVE() {
	ARCHIVE="$1"
	MD5_FILE="$2"
	INSTALL_DIR="$3"
	GLOB="$4"
	TGT_BIN="$5"

	[ -e "$ARCHIVE" ] || return 0

	EXPECTED_MD5=$(cat "$MD5_FILE" 2>/dev/null) || return 0

	CURRENT_MD5=
	[ -f "$TGT_BIN" ] && {
		CURRENT_MD5=$(md5sum "$TGT_BIN" 2>/dev/null)
		CURRENT_MD5=${CURRENT_MD5%% *}
	}

	[ "$CURRENT_MD5" = "$EXPECTED_MD5" ] && return 0

	_INST_TMP=$(mktemp -d "${INSTALL_DIR}/tmp.XXXXXX") || return 1
	gzip -dc -- "$ARCHIVE" | tar -xf - -C "$_INST_TMP"

	SRC_BIN=$(find "$_INST_TMP" -maxdepth 1 -type f -name "$GLOB" | head -n 1)

	if [ -n "$SRC_BIN" ]; then
		TGT_TMP=$(mktemp "${TGT_BIN}.XXXXXX") || {
			rm -rf "$_INST_TMP"
			return 1
		}
		if cp -f "$SRC_BIN" "$TGT_TMP" && chmod +x "$TGT_TMP" && mv -f "$TGT_TMP" "$TGT_BIN"; then
			:
		else
			rm -f "$TGT_TMP"
			rm -rf "$_INST_TMP"
			return 1
		fi
	else
		printf "Error: no %s binary found in %s\n" "$GLOB" "$ARCHIVE" >&2
	fi

	rm -rf "$_INST_TMP"
}

RUN_EMULATOR_MAINTENANCE() {
	EMU_VER=$1
	MAINTENANCE_RESULT=0

	RA_DIR="$MUOS_SHARE_DIR/emulator/retroarch"
	INSTALL_BIN "$RA_DIR/retroarch-${EMU_VER}" "$RA_DIR/retroarch-${EMU_VER}.md5" "/usr/bin/retroarch" &
	RA_PID=$!

	PPSSPP_DIR="$MUOS_SHARE_DIR/emulator/ppsspp"
	INSTALL_ARCHIVE "${PPSSPP_DIR}/PPSSPP-${EMU_VER}.tar.gz" "${PPSSPP_DIR}/PPSSPP-${EMU_VER}.md5" \
		"$PPSSPP_DIR" "PPSSPP-*" "${PPSSPP_DIR}/PPSSPP" &
	PPSSPP_PID=$!

	SCUMMVM_DIR="$MUOS_SHARE_DIR/emulator/scummvm"
	INSTALL_ARCHIVE "${SCUMMVM_DIR}/scummvm-${EMU_VER}.tar.gz" "${SCUMMVM_DIR}/scummvm-${EMU_VER}.md5" \
		"$SCUMMVM_DIR" "scummvm-*" "${SCUMMVM_DIR}/scummvm" &
	SCUMMVM_PID=$!

	for MAINTENANCE_PID in "$RA_PID" "$PPSSPP_PID" "$SCUMMVM_PID"; do
		wait "$MAINTENANCE_PID" || MAINTENANCE_RESULT=1
	done

	return "$MAINTENANCE_RESULT"
}

INSTALL_EMULATORS() {
	[ -n "$1" ] || return 0
	RUN_EMULATOR_MAINTENANCE "$1" || return 1
	EMULATOR_SOURCES "$1" >"$EMULATOR_STAMP"
}
