#!/bin/sh

[ "$#" -eq 2 ] || exit 2
[ -f "$2" ] || exec mv -f "$1" "$2"

ASIDE="$2.replace-$$"
mv -f "$2" "$ASIDE" || exit 1

if ! mv -f "$1" "$2"; then
	mv -f "$ASIDE" "$2"
	exit 1
fi

rm -f "$ASIDE"
