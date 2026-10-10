#!/bin/sh
# HELP: Bluetooth Report - Checks the Bluetooth adapter, service and paired devices, then saves a report to SD1
# ICON: diagnostic
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

. /opt/muos/script/var/diag.sh

DIAG_BEGIN "bluetooth_report" "Bluetooth Report"

DIAG_SECTION "Bluetooth checks"
if [ "$(GET_VAR "device" "board/bluetooth" 2>/dev/null)" != "1" ]; then
	DIAG_OUT "This device has no Bluetooth hardware."
	DIAG_FINISH "Bluetooth report saved"
	exit 0
fi
BT_OUTPUT=$(/opt/muos/script/mux/bt_diag.sh run 2>&1)
printf '%s\n' "$BT_OUTPUT" | DIAG_TEE
while IFS= read -r BT_LINE; do
	case "$BT_LINE" in
		*"[FAIL]"*) DIAG_FINDING "BLUETOOTH" "$(printf '%s' "${BT_LINE#*\[FAIL\]}" | sed 's/^ *//')" ;;
	esac
done <<BT_EOF
$BT_OUTPUT
BT_EOF

DIAG_SECTION "Kernel messages"
DIAG_DMESG "bluetooth|hci|btusb|rtk_|xradio|bt_" 40

DIAG_FINISH "Bluetooth report saved"
exit 0
