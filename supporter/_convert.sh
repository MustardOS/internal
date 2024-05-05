#!/bin/sh

mkdir RESIZED_IMAGES 2>/dev/null

for IMAGE in *.[pP][nN][gG] *.[jJ][pP][gG] *.[jJ][pP][eE][gG] *.[gG][iI][fF]; do
	if [ -f "$IMAGE" ]; then
		FILENAME=$(basename "$IMAGE" | sed 's/\.[^.]*$//')
		case "$IMAGE" in
			*.gif|*.GIF)
				convert "$IMAGE[0]" -resize 256x256 "RESIZED_IMAGES/${FILENAME}.png"
				;;
			*)
				convert "$IMAGE" -resize 256x256 "RESIZED_IMAGES/${FILENAME}.png"
				;;
		esac
		pngcrush -ow "RESIZED_IMAGES/${FILENAME}.png"
	fi
done
