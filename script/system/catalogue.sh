#!/bin/sh

# Initialise the ini parser
. /opt/muos/script/system/parse.sh

# Define path ot muOS core ini files
CurrentFile="/mnt/mmc/MUOS/info/assign/*.ini"

# Check if any .ini files are found
set -- $CurrentFile
if [ $# -eq 0 ]; then
    exit 1
fi

# Extract catalogue value from core ini and create appropriate folders
create_directories_from_ini() {
    ini_file="$1"

    # Extract the catalogue value using parse_ini function from parse.sh
    catalogue=$(parse_ini "$ini_file" "global" "catalogue")

    if [ -z "$catalogue" ]; then
        return
    fi

    # Define the base system directory
    base_dir="/mnt/mmc/MUOS/info/catalogue/$catalogue"

    # Create the base directory and subdirectories
    mkdir -p "$base_dir/box" "$base_dir/preview" "$base_dir/text"

}

# Process each .ini file and create directories
for ini_file in $CurrentFile; do
    create_directories_from_ini "$ini_file"
done
