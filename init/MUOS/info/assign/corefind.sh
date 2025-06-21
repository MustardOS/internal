#!/bin/sh

find . -type f -name "*.ini" | while IFS= read -r FILE; do
    grep -E '^core=' "$FILE" | while IFS= read -r LINE; do
        VALUE=${LINE#core=}
        [ -n "$VALUE" ] && printf "%s\n" "$VALUE"
    done
done
