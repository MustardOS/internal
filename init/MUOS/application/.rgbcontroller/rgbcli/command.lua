local command = {}

local tables = require("tables")

-- Convert brightness from 1-10 to 0-255 scale
local function convertBrightness(brightness)
    return math.floor((brightness) * 25.5)
end

-- Construct and run the command based on settings
function command.run(settings, colors, double_colors)
    -- Base command structure, without the path repetition
    local mode = settings.mode
    local brightness = convertBrightness(settings.brightness)
    local color = colors[settings.color].rgb
    local speed = settings.speed * 5
    local commandArgs = ""

    -- Append mode and color parameters based on the current mode
    if mode == 1 then
        commandArgs = string.format("1 0 0 0 0 0 0 0")
    elseif mode == 2 then
        commandArgs = string.format("1 %d %d %d %d %d %d %d", brightness, color[1], color[2], color[3], color[1], color[2], color[3])
    elseif mode == 3 then
        commandArgs = string.format("2 %d %d %d %d", brightness, color[1], color[2], color[3])
    elseif mode == 4 then
        commandArgs = string.format("3 %d %d %d %d", brightness, color[1], color[2], color[3])
    elseif mode == 5 then
        commandArgs = string.format("4 %d %d %d %d", brightness, color[1], color[2], color[3])
    elseif mode == 6 then
        local comboIndex = settings.combo
        local comboColors = double_colors[comboIndex].rgb
        commandArgs = string.format("1 %d %d %d %d %d %d %d", brightness, comboColors[1], comboColors[2], comboColors[3], comboColors[4], comboColors[5], comboColors[6])
    elseif mode == 7 then
        commandArgs = string.format("5 %d %d", brightness, speed)
    elseif mode == 8 then
        commandArgs = string.format("6 %d %d", brightness, speed)
    end

    -- Define the path to the folder and the command file
    local folderPath = "/run/muos/storage/theme/active/rgb"
    local commandFile = folderPath .. "/rgbconf.sh"

    -- Ensure the directory exists
    os.execute("mkdir -p " .. folderPath)

    -- Open the file for writing
    local file = io.open(commandFile, "w")
    if file then
        -- Add the shebang at the beginning
        file:write("#!/bin/sh\n")

        -- Add the dynamic device-specific path with the correct arguments
        file:write(string.format("/opt/muos/device/current/script/led_control.sh %s\n", commandArgs))

        file:close()
        print("Command saved to: " .. commandFile)
    else
        print("Error: Could not save the file.")
    end

    -- Print the final command to the console for debugging
    print("Running command: /opt/muos/device/current/script/led_control.sh " .. commandArgs)

    -- Execute the command in the system shell
    os.execute("/run/muos/storage/theme/active/rgb/rgbconf.sh")
end

return command
