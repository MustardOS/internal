#!/bin/sh

[ -n "${MUOS_MANIFEST_LOADED-}" ] && return 0
MUOS_MANIFEST_LOADED=1
[ -n "${MUOS_BASE_LOADED-}" ] || . "${MUOS_VAR_DIR:-/opt/muos/script/var}/base.sh"

# Each system has its own definition file named after its system key, inside a folder named after
# its namespace, such as 'Atari/Atari 2600.json'. A file with the same system key anywhere in the
# user folder replaces that one system and takes the namespace of its own folder, and new system
# keys add systems.
CORE_MANIFEST_DIR="$MUOS_SHARE_DIR/info/manifest/core"
CORE_MANIFEST_USER="$MUOS_STORE_DIR/info/manifest/core"

CORE_MANIFEST_VALID() {
	[ -r "$1" ] && jq -e 'type == "object"' "$1" >/dev/null 2>&1
}

# Prints the first valid definition file for a system key below a manifest folder
CORE_MANIFEST_FIND() {
	for CM_FOUND in "$1"/*/"$2.json"; do
		CORE_MANIFEST_VALID "$CM_FOUND" || continue
		printf '%s' "$CM_FOUND"
		return 0
	done

	return 1
}

# Prints the definition file used for one system, the user copy winning over the bundled one
CORE_MANIFEST_FILE() {
	case "$1" in "" | .* | */*) return 1 ;; esac

	CORE_MANIFEST_FIND "$CORE_MANIFEST_USER" "$1" || CORE_MANIFEST_FIND "$CORE_MANIFEST_DIR" "$1"
}

# Prints every system as one object keyed by system key, with the namespace taken from its folder,
# so jq filters written for the old single file keep working when piped through this
CORE_MANIFEST_MERGED() {
	set --

	for CM_FILE in "$CORE_MANIFEST_DIR"/*/*.json; do
		[ -r "$CM_FILE" ] || continue
		CM_KEY=${CM_FILE##*/}
		CM_KEY=${CM_KEY%.json}

		if CM_USER=$(CORE_MANIFEST_FIND "$CORE_MANIFEST_USER" "$CM_KEY"); then
			set -- "$@" "$CM_USER"
		else
			set -- "$@" "$CM_FILE"
		fi
	done

	for CM_USER in "$CORE_MANIFEST_USER"/*/*.json; do
		CM_KEY=${CM_USER##*/}
		CM_KEY=${CM_KEY%.json}

		CORE_MANIFEST_FIND "$CORE_MANIFEST_DIR" "$CM_KEY" >/dev/null && continue
		[ "$(CORE_MANIFEST_FIND "$CORE_MANIFEST_USER" "$CM_KEY")" = "$CM_USER" ] && set -- "$@" "$CM_USER"
	done

	[ "$#" -gt 0 ] || return 1

	jq -n 'reduce inputs as $s ({}; (input_filename | split("/")) as $p
		| .[$p[-1] | rtrimstr(".json")] = ($s + {namespace: $p[-2]}))' "$@"
}

# Writes one system from an older layout into the user folder, unless it matches the bundled
# system, so the rest follow future updates
CORE_MANIFEST_KEEP() {
	CM_DATA=$1
	CM_KEY=$2

	CM_NS=$(printf '%s' "$CM_DATA" | jq -r '.namespace // "Other"')
	case "$CM_NS" in "" | .* | */*) CM_NS="Other" ;; esac

	CM_SYSTEM=$(printf '%s' "$CM_DATA" | jq '{catalogue: (.catalogue // .name)} + del(.name, .namespace, .catalogue)')

	if CM_BUNDLED=$(CORE_MANIFEST_FIND "$CORE_MANIFEST_DIR" "$CM_KEY"); then
		CM_BUNDLED_NS=${CM_BUNDLED%/*}
		CM_BUNDLED_NS=${CM_BUNDLED_NS##*/}

		[ "$CM_NS" = "$CM_BUNDLED_NS" ] &&
			printf '%s' "$CM_SYSTEM" | jq -e --slurpfile b "$CM_BUNDLED" '. == $b[0]' >/dev/null 2>&1 && return 0
	fi

	CM_USER="$CORE_MANIFEST_USER/$CM_NS/$CM_KEY.json"
	mkdir -p "$CORE_MANIFEST_USER/$CM_NS" &&
		printf '%s\n' "$CM_SYSTEM" | jq --indent 4 . >"$CM_USER.tmp" && mv -f "$CM_USER.tmp" "$CM_USER"
}

# Moves user system files from older layouts into namespace folders: a single core.json, which is
# renamed afterwards, and system files sitting directly in the user folder
CORE_MANIFEST_MIGRATE() {
	CM_OLD="$MUOS_STORE_DIR/info/manifest/core.json"

	if [ -f "$CM_OLD" ]; then
		if CORE_MANIFEST_VALID "$CM_OLD"; then
			jq -r 'keys[]' "$CM_OLD" | while IFS= read -r CM_KEY; do
				case "$CM_KEY" in "" | .* | */*) continue ;; esac
				CORE_MANIFEST_FIND "$CORE_MANIFEST_USER" "$CM_KEY" >/dev/null && continue

				CORE_MANIFEST_KEEP "$(jq --arg k "$CM_KEY" '.[$k]' "$CM_OLD")" "$CM_KEY"
			done
		fi

		mv -f "$CM_OLD" "$CM_OLD.old"
	fi

	for CM_FLAT in "$CORE_MANIFEST_USER"/*.json; do
		[ -f "$CM_FLAT" ] || continue
		CM_KEY=${CM_FLAT##*/}
		CM_KEY=${CM_KEY%.json}

		if CORE_MANIFEST_VALID "$CM_FLAT" && ! CORE_MANIFEST_FIND "$CORE_MANIFEST_USER" "$CM_KEY" >/dev/null; then
			CORE_MANIFEST_KEEP "$(cat "$CM_FLAT")" "$CM_KEY"
		fi

		mv -f "$CM_FLAT" "$CM_FLAT.old"
	done
}
