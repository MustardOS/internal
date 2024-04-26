#!/bin/sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

/opt/muos/script/mux/track.sh "$NAME" \""/$ROM"\"

