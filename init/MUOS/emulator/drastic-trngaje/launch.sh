#!/bin/sh

DRASTIC_DIR=$(dirname "$0")
export LD_LIBRARY_PATH=$DRASTIC_DIR/libs:$LD_LIBRARY_PATH

cd "$DRASTIC_DIR" || exit 1
./drastic "$1"

U_DATA="/userdata"
[ -d "$U_DATA" ] && rm -rf "$U_DATA"
