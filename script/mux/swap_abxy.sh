#!/bin/sh

RA_CONF=$1
if [ ! -f "$RA_CONF" ] || [ ! -w "$RA_CONF" ]; then
	printf "Usage: %s <RA Config (.cfg)>\n" "$0" >&2
	exit 1
fi

GET_RA_VAL() {
	grep -E "^$1[[:space:]]*=" "$RA_CONF" | head -n 1 | sed -n 's/^[^=]*=[[:space:]]*"\(.*\)"/\1/p'
}

SET_RA_VAL() {
	ESC=$(printf '%s' "$2" | sed 's/[\\|&]/\\&/g')
	sed -i "s|^$1[[:space:]]*=.*|$1 = \"$ESC\"|" "$RA_CONF"
}

# Capture all current values...
A_VAL=$(GET_RA_VAL "input_player1_a")
A_AXIS_VAL=$(GET_RA_VAL "input_player1_a_axis")
A_BTN_VAL=$(GET_RA_VAL "input_player1_a_btn")
A_MBTN_VAL=$(GET_RA_VAL "input_player1_a_mbtn")

B_VAL=$(GET_RA_VAL "input_player1_b")
B_AXIS_VAL=$(GET_RA_VAL "input_player1_b_axis")
B_BTN_VAL=$(GET_RA_VAL "input_player1_b_btn")
B_MBTN_VAL=$(GET_RA_VAL "input_player1_b_mbtn")

X_VAL=$(GET_RA_VAL "input_player1_x")
X_AXIS_VAL=$(GET_RA_VAL "input_player1_x_axis")
X_BTN_VAL=$(GET_RA_VAL "input_player1_x_btn")
X_MBTN_VAL=$(GET_RA_VAL "input_player1_x_mbtn")

Y_VAL=$(GET_RA_VAL "input_player1_y")
Y_AXIS_VAL=$(GET_RA_VAL "input_player1_y_axis")
Y_BTN_VAL=$(GET_RA_VAL "input_player1_y_btn")
Y_MBTN_VAL=$(GET_RA_VAL "input_player1_y_mbtn")

# Gotta be an easier way...?
SWAP() {
	BTN=$1
	SUF=$2
	case $BTN in
		a)
			case $SUF in
				"") printf %s "$A_VAL" ;;
				_axis) printf %s "$A_AXIS_VAL" ;;
				_btn) printf %s "$A_BTN_VAL" ;;
				_mbtn) printf %s "$A_MBTN_VAL" ;;
			esac
			;;
		b)
			case $SUF in
				"") printf %s "$B_VAL" ;;
				_axis) printf %s "$B_AXIS_VAL" ;;
				_btn) printf %s "$B_BTN_VAL" ;;
				_mbtn) printf %s "$B_MBTN_VAL" ;;
			esac
			;;
		x)
			case $SUF in
				"") printf %s "$X_VAL" ;;
				_axis) printf %s "$X_AXIS_VAL" ;;
				_btn) printf %s "$X_BTN_VAL" ;;
				_mbtn) printf %s "$X_MBTN_VAL" ;;
			esac
			;;
		y)
			case $SUF in
				"") printf %s "$Y_VAL" ;;
				_axis) printf %s "$Y_AXIS_VAL" ;;
				_btn) printf %s "$Y_BTN_VAL" ;;
				_mbtn) printf %s "$Y_MBTN_VAL" ;;
			esac
			;;
	esac
}

for SUF in "" _axis _btn _mbtn; do
	# A>B
	SET_RA_VAL "input_player1_a${SUF}" "$(SWAP b "$SUF")"
	# B>A
	SET_RA_VAL "input_player1_b${SUF}" "$(SWAP a "$SUF")"
	# X>Y
	SET_RA_VAL "input_player1_x${SUF}" "$(SWAP y "$SUF")"
	# Y>X
	SET_RA_VAL "input_player1_y${SUF}" "$(SWAP x "$SUF")"
done
