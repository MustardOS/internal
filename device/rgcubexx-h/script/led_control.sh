#!/bin/bash

# Define the serial device
SERIAL_DEVICE="/dev/ttyS5"

# Display LED mode descriptions and usage examples if no parameters are provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <led_mode> <brightness_value> [<speed_value>|<r_value> <g_value> <b_value> [<joystick_r> <joystick_g> <joystick_b>]]"
  echo "LED Modes:"
  echo "1: Solid Color (no effects)"
  echo "   Usage: $0 1 <brightness_value> <right_joystick_r> <right_joystick_g> <right_joystick_b> <left_joystick_r> <left_joystick_g> <left_joystick_b>"
  echo "   Example: $0 1 255 255 0 0 0 0 255   # Right joystick color red, left joystick color blue"
  echo "   Randomize: $0 1 <brightness_value> randomize"
  echo "   Example: $0 1 255 randomize  # Randomize RGB values and send to /dev/ttyS5 until stopped"
  echo "2: Solid Color (Breathing, Fast)"
  echo "   Usage: $0 2 <brightness_value> <r_value> <g_value> <b_value>"
  echo "   Example: $0 2 255 0 255 0   # Green color at maximum brightness with fast breathing effect"
  echo "3: Solid Color (Breathing, Medium)"
  echo "   Usage: $0 3 <brightness_value> <r_value> <g_value> <b_value>"
  echo "   Example: $0 3 255 0 0 255   # Blue color at maximum brightness with medium breathing effect"
  echo "4: Solid Color (Breathing, Slow)"
  echo "   Usage: $0 4 <brightness_value> <r_value> <g_value> <b_value>"
  echo "   Example: $0 4 255 255 255 0   # Yellow color at maximum brightness with slow breathing effect"
  echo "5: Monochromatic Rainbow (Cycle between RGB colors)"
  echo "   Usage: $0 5 <brightness_value> <speed_value>"
  echo "   Example: $0 5 255 100   # Monochromatic rainbow effect at maximum brightness with speed 100"
  echo "6: Multicolor Rainbow (Rainbow Swirl effect)"
  echo "   Usage: $0 6 <brightness_value> <speed_value>"
  echo "   Example: $0 6 255 100   # Multicolor rainbow swirl effect at maximum brightness with speed 100"
  exit 0
fi

# Open the serial device
exec 20<>$SERIAL_DEVICE

# Configure the serial device
stty -F $SERIAL_DEVICE 115200 -opost -isig -icanon -echo

# Ensure MCU has power enabled
echo 1 > /sys/class/power_supply/axp2202-battery/mcu_pwr
#echo 1 > /sys/class/power_supply/axp2202-battery/mcu_esckey
sleep 0.05

# Ensure correct number of arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <led_mode> <brightness_value> [<speed_value>|<r_value> <g_value> <b_value> [<joystick_r> <joystick_g> <joystick_b>]]"
  exit 1
fi

LED_MODE=$1
BRIGHTNESS=$2

# Ensure brightness is within the valid range (0-255)
if [ $BRIGHTNESS -lt 0 ] || [ $BRIGHTNESS -gt 255 ]; then
  echo "Brightness value must be between 0 and 255"
  exit 1
fi

# Ensure LED mode is within the valid range (1-6)
if [ $LED_MODE -lt 1 ] || [ $LED_MODE -gt 6 ]; then
  echo "LED mode must be between 1 and 6"
  exit 1
fi

# Function to calculate checksum
calculate_checksum() {
  local sum=0
  for byte in "$@"; do
    sum=$((sum + byte))
  done
  echo $((sum & 0xFF))
}

# Function to generate random RGB values
generate_random_rgb() {
  echo $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
}

# Function to read key press
key_pressed() {
  read -t 0.001 -n 1 && return 0 || return 1
}

# Construct payload based on LED mode
if [ $LED_MODE -ge 5 ] && [ $LED_MODE -le 6 ]; then
  # Ensure speed is provided for modes 5 and 6
  if [ $# -ne 3 ]; then
    echo "Usage for modes 5 and 6: $0 <led_mode> <brightness_value> <speed_value>"
    exit 1
  fi

  SPEED=$3

  # Ensure speed is within the valid range (0-255)
  if [ $SPEED -lt 0 ] || [ $SPEED -gt 255 ]; then
    echo "Speed value must be between 0 and 255"
    exit 1
  fi

  # Calculate the checksum
  CHECKSUM=$(calculate_checksum $LED_MODE $BRIGHTNESS 1 1 $SPEED)

  # Construct the payload
  PAYLOAD=$(printf '\\x%02X\\x%02X\\x%02X\\x%02X\\x%02X\\x%02X' $LED_MODE $BRIGHTNESS 1 1 $SPEED $CHECKSUM)

elif [ $LED_MODE -eq 1 ] && [ "$3" == "randomize" ]; then
  # Randomize mode for LED mode 1
  echo "Press any key to stop..."
  while :; do
    read RIGHT_R RIGHT_G RIGHT_B < <(generate_random_rgb)
    read LEFT_R LEFT_G LEFT_B < <(generate_random_rgb)
    
    # Construct the payload for RGB and joystick values
    PAYLOAD=$(printf '\\x%02X\\x%02X' $LED_MODE $BRIGHTNESS)
    for ((i = 0; i < 8; i++)); do
      PAYLOAD+=$(printf '\\x%02X\\x%02X\\x%02X' $RIGHT_R $RIGHT_G $RIGHT_B)
    done
    for ((i = 0; i < 8; i++)); do
      PAYLOAD+=$(printf '\\x%02X\\x%02X\\x%02X' $LEFT_R $LEFT_G $LEFT_B)
    done

    # Calculate checksum for the payload
    PAYLOAD_BYTES=($LED_MODE $BRIGHTNESS)
    for ((i = 0; i < 8; i++)); do
      PAYLOAD_BYTES+=($RIGHT_R $RIGHT_G $RIGHT_B)
    done
    for ((i = 0; i < 8; i++)); do
      PAYLOAD_BYTES+=($LEFT_R $LEFT_G $LEFT_B)
    done
    CHECKSUM=$(calculate_checksum "${PAYLOAD_BYTES[@]}")
    PAYLOAD+=$(printf '\\x%02X' $CHECKSUM)

    # Write the payload to the serial device
    echo -e -n "$PAYLOAD" > $SERIAL_DEVICE

    # Check for key press to exit
    if key_pressed; then
      echo "Randomize mode stopped."
      break
    fi
  done
elif [ $LED_MODE -eq 1 ]; then
  # Ensure RGB and joystick values are provided for mode 1
  if [ $# -ne 8 ]; then
    echo "Usage for mode 1: $0 <led_mode> <brightness_value> <right_joystick_r> <right_joystick_g> <right_joystick_b> <left_joystick_r> <left_joystick_g> <left_joystick_b>"
    exit 1
  fi

  RIGHT_R=$3
  RIGHT_G=$4
  RIGHT_B=$5
  LEFT_R=$6
  LEFT_G=$7
  LEFT_B=$8

  # Ensure RGB values are within the valid range (0-255)
  if [ $RIGHT_R -lt 0 ] || [ $RIGHT_R -gt 255 ] || [ $RIGHT_G -lt 0 ] || [ $RIGHT_G -gt 255 ] || [ $RIGHT_B -lt 0 ] || [ $RIGHT_B -gt 255 ]; then
    echo "RGB values must be between 0 and 255"
    exit 1
  fi

  # Ensure joystick RGB values are within the valid range (0-255)
  if [ $LEFT_R -lt 0 ] || [ $LEFT_R -gt 255 ] || [ $LEFT_G -lt 0 ] || [ $LEFT_G -gt 255 ] || [ $LEFT_B -lt 0 ] || [ $LEFT_B -gt 255 ]; then
    echo "Joystick RGB values must be between 0 and 255"
    exit 1
  fi

  # Construct the payload for RGB and joystick values
  PAYLOAD=$(printf '\\x%02X\\x%02X' $LED_MODE $BRIGHTNESS)
  for ((i = 0; i < 8; i++)); do
    PAYLOAD+=$(printf '\\x%02X\\x%02X\\x%02X' $RIGHT_R $RIGHT_G $RIGHT_B)
  done
  for ((i = 0; i < 8; i++)); do
    PAYLOAD+=$(printf '\\x%02X\\x%02X\\x%02X' $LEFT_R $LEFT_G $LEFT_B)
  done

  # Calculate checksum for the payload
  PAYLOAD_BYTES=($LED_MODE $BRIGHTNESS)
  for ((i = 0; i < 8; i++)); do
    PAYLOAD_BYTES+=($RIGHT_R $RIGHT_G $RIGHT_B)
  done
  for ((i = 0; i < 8; i++)); do
    PAYLOAD_BYTES+=($LEFT_R $LEFT_G $LEFT_B)
  done
  CHECKSUM=$(calculate_checksum "${PAYLOAD_BYTES[@]}")
  PAYLOAD+=$(printf '\\x%02X' $CHECKSUM)

else
  # Ensure RGB values are provided for modes 2-4
  if [ $# -ne 5 ]; then
    echo "Usage for modes 2-4: $0 <led_mode> <brightness_value> <r_value> <g_value> <b_value>"
    exit 1
  fi

  R_VALUE=$3
  G_VALUE=$4
  B_VALUE=$5

  # Ensure RGB values are within the valid range (0-255)
  if [ $R_VALUE -lt 0 ] || [ $R_VALUE -gt 255 ] || [ $G_VALUE -lt 0 ] || [ $G_VALUE -gt 255 ] || [ $B_VALUE -lt 0 ] || [ $B_VALUE -gt 255 ]; then
    echo "RGB values must be between 0 and 255"
    exit 1
  fi

  # Construct the payload for RGB values
  PAYLOAD=$(printf '\\x%02X\\x%02X' $LED_MODE $BRIGHTNESS)
  for ((i = 0; i < 16; i++)); do
    PAYLOAD+=$(printf '\\x%02X\\x%02X\\x%02X' $R_VALUE $G_VALUE $B_VALUE)
  done

  # Calculate checksum for the payload
  PAYLOAD_BYTES=($LED_MODE $BRIGHTNESS)
  for ((i = 0; i < 16; i++)); do
    PAYLOAD_BYTES+=($R_VALUE $G_VALUE $B_VALUE)
  done
  CHECKSUM=$(calculate_checksum "${PAYLOAD_BYTES[@]}")
  PAYLOAD+=$(printf '\\x%02X' $CHECKSUM)
fi

# Debugging output
echo "Debug: Payload is $PAYLOAD"
echo "Debug: Command to be executed: echo -e -n \"$PAYLOAD\" > $SERIAL_DEVICE"

# Write the payload to the serial device
echo -e -n "$PAYLOAD" > $SERIAL_DEVICE

echo "LED mode $LED_MODE set with brightness $BRIGHTNESS"

# Close the serial device
exec 20>&-
