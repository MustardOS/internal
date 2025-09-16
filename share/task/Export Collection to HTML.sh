#!/bin/sh
# HELP: Export collection list, including boxart if found, to a file called "collection.html" at the root of SD1
# ICON: star

. /opt/muos/script/var/func.sh

FRONTEND stop

COLLECTION_DIR="/run/muos/storage/info/collection"
COLLECTION_OUTPUT="$(GET_VAR "device" "storage/rom/mount")/collection.html"
THEME_TEMPLATE="/run/muos/storage/theme/active/collect.html"
FALLBACK_TEMPLATE="$MUOS_SHARE_DIR/media/collect.html"
TEMP_SECTIONS="/tmp/sections.html"
TEMP_TEMPLATE="/tmp/template_collect.tmp"

ESCAPE_HTML() {
	case $1 in
		*\&* | *\<* | *\>* | *\"* | *\'*)
			printf '%s\n' "$1" | sed \
				-e 's/&/\&amp;/g' \
				-e 's/</\&lt;/g' \
				-e 's/>/\&gt;/g' \
				-e 's/"/\&quot;/g' \
				-e "s/'/\&#39;/g"
			;;
		*) printf '%s\n' "$1" ;;
	esac
}

RENDER_SECTION() {
	SECTION_NAME=$1
	FILES_PATH=$2

	echo "Processing section: $SECTION_NAME" >&2

	FILE_COUNT=$(find "$FILES_PATH" -mindepth 1 -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
	[ "$FILE_COUNT" -eq 0 ] && {
		echo "  Skipping empty section: $SECTION_NAME" >&2
		return
	}

	SECTION_ID=$(echo "$SECTION_NAME" | tr '/ .' '__')
	ESCAPED_HEADER=$(ESCAPE_HTML "$SECTION_NAME ($FILE_COUNT Item$([ "$FILE_COUNT" -ne 1 ] && printf 's'))")

	printf '\t<div class="section">\n'
	printf '\t\t<button class="collapsible">%s</button>\n' "$ESCAPED_HEADER"
	printf '\t\t<div id="%s" class="content" style="display: block;">\n' "$SECTION_ID"
	printf '\t\t\t<div class="container">\n'

	find "$FILES_PATH" -mindepth 1 -maxdepth 1 -type f | sort | while IFS= read -r ENTRY; do
		CFG_PATH=$(sed -n '1p' "$ENTRY")
		if [ -f "$CFG_PATH" ]; then
			SYSTEM_NAME=$(sed -n '3p' "$CFG_PATH")
			GAME_NAME=$(sed -n '1p' "$CFG_PATH")

			if [ -n "$GAME_NAME" ] && [ -n "$SYSTEM_NAME" ]; then
				DISPLAY_NAME="[$SYSTEM_NAME] $GAME_NAME"
				echo "  Adding: $DISPLAY_NAME" >&2

				ESCAPED_FILE=$(ESCAPE_HTML "$DISPLAY_NAME")
				printf '\t\t\t\t<div class="game-card">\n'
				printf '\t\t\t\t\t<div class="game-label">%s</div>\n' "$ESCAPED_FILE"

				IMG_PATH="/run/muos/storage/info/catalogue/$SYSTEM_NAME/box/$GAME_NAME.png"
				if [ -f "$IMG_PATH" ]; then
					echo "    Encoding image: $IMG_PATH" >&2
					printf '\t\t\t\t\t<div class="game-preview"><img src="data:image/webp;base64,'
					cwebp -quiet "$IMG_PATH" -o - | base64 | tr -d '\n'
					printf '" /></div>\n'
				else
					echo "    No image found for: $GAME_NAME" >&2
				fi

				printf '\t\t\t\t</div>\n'
			else
				echo "    Invalid config: $ENTRY" >&2
			fi
		else
			echo "    Missing config path from: $ENTRY" >&2
		fi
	done

	printf '\t\t\t</div>\n\t\t</div>\n\t</div>\n'
}

echo "Clearing previous section output..."
: >"$TEMP_SECTIONS"

echo "Scanning directories in $COLLECTION_DIR..."
find "$COLLECTION_DIR" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r SUB_DIR; do
	SECTION_NAME=$(basename "$SUB_DIR")
	RENDER_SECTION "$SECTION_NAME" "$SUB_DIR" >>"$TEMP_SECTIONS"
done

echo "Processing unsorted items..."
RENDER_SECTION "Unsorted" "$COLLECTION_DIR" >>"$TEMP_SECTIONS"

echo "Using template..."
if [ -f "$THEME_TEMPLATE" ]; then
	echo "  Using theme template: $THEME_TEMPLATE"
	cp "$THEME_TEMPLATE" "$TEMP_TEMPLATE"
else
	echo "  Using built-in template: $FALLBACK_TEMPLATE"
	cp "$FALLBACK_TEMPLATE" "$TEMP_TEMPLATE"
fi

echo "Substituting placeholders..."
sed "s/{{TITLE}}/Content Collection/g" "$TEMP_TEMPLATE" | while IFS= read -r LINE; do
	case "$LINE" in
		*"{{SECTIONS}}"*)
			cat "$TEMP_SECTIONS"
			;;
		*)
			printf '%s\n' "$LINE"
			;;
	esac
done >"$COLLECTION_OUTPUT"

echo "Collection list written to $COLLECTION_OUTPUT"

echo "Sync Filesystem"
sync

echo "All Done!"
TBOX sleep 2

FRONTEND start task
exit 0

