#!/bin/sh

. /opt/muos/script/var/func.sh

DRASTIC_DIR=$(dirname "$0")
DRASTIC_LIB="$DRASTIC_DIR/libs"

case "$(GET_VAR "device" "board/name")" in
	rg*) DRASTIC_LIB="${DRASTIC_LIB}/rg" ;;
	tui*) DRASTIC_LIB="${DRASTIC_LIB}/tui" ;;
esac

export LD_LIBRARY_PATH=$DRASTIC_LIB:$LD_LIBRARY_PATH

cd "$DRASTIC_DIR" || exit 1
./drastic "$1"

U_DATA="/userdata"
[ -d "$U_DATA" ] && rm -rf "$U_DATA"
