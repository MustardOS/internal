local command = require("command")
local tables = require("tables")

local modes = tables.modes
local colors = tables.colors
local settings = tables.settings
local menu = tables.menu

-- Load the settings from a file
function loadSettings()
    local filePath = "/run/muos/storage/theme/active/rgb/settings.txt"
    local file = io.open(filePath, "r")
    
    if file then
        local contents = file:read("*all")
        file:close()
        
        if contents then
            parseSettings(contents)
        else
            print("Failed to read settings file.")
        end
    else
        print("Settings file not found.")
    end
end

-- Parse the settings from the file
function parseSettings(contents)
    for line in contents:gmatch("[^\r\n]+") do
        local key, value = line:match("(%w+)=(%d+)")
        if key and value then
            settings[key] = tonumber(value)
        end
    end
end

-- Convert brightness from 1-10 to 0-255 scale
local function convertBrightness(brightness)
    return math.floor((brightness - 1) * 25.5)
end

-- Function to save the settings to a file
local function saveSettings()
    local settingsData = string.format(
        "mode=%d\ncolor=%d\ncombo=%d\nbrightness=%d\nspeed=%d",
        settings.mode,
        settings.color,
        settings.combo,
        settings.brightness,
        settings.speed
    )
    
    local filePath = "/run/muos/storage/theme/active/rgb/settings.txt"
    local file = io.open(filePath, "w")
    
    if file then
        file:write(settingsData)
        file:close()
    else
        print("Failed to open file for writing.")
    end
end

-- Helper function to adjust settings with or without wraparound
local function changeSetting(currentValue, minValue, maxValue, direction, wraparound)
    if direction == "up" then
        currentValue = currentValue + 1
        if currentValue > maxValue then
            if wraparound then
                currentValue = minValue  -- Wrap around to the start
            else
                currentValue = maxValue -- Stay at max value (no wraparound)
            end
        end
    elseif direction == "down" then
        currentValue = currentValue - 1
        if currentValue < minValue then
            if wraparound then
                currentValue = maxValue -- Wrap around to the end
            else
                currentValue = minValue -- Stay at min value (no wraparound)
            end
        end
    end
    return currentValue
end

-- Function to handle command-line arguments
local function handleCLIArgs(args)
    -- Load settings before processing any arguments
    loadSettings()

    -- Map short flags to the actual commands
    local flagToCommand = {
        ["-b"] = "brightness",
        ["-m"] = "mode",
        ["-c"] = "color_or_combo",  -- Changed from "color" to "color_or_combo"
        ["-s"] = "speed"  -- Removed -o flag
    }

    local commandTriggered = false

    -- Define valid commands and the logic to update settings
    local validCommands = {
        ["mode"] = function(direction)
            settings.mode = changeSetting(settings.mode, 1, #modes, direction, true)
            print("Mode changed to " .. settings.mode)
        end,
        ["color_or_combo"] = function(direction)
            -- Change color for modes 2-5, combo for mode 6
            if settings.mode >= 2 and settings.mode <= 5 then
                settings.color = changeSetting(settings.color, 1, #colors, direction, false)
                print("Color changed to " .. settings.color)
            elseif settings.mode == 6 then
                settings.combo = changeSetting(settings.combo, 1, #tables.double_colors, direction, false)
                print("Combo changed to " .. settings.combo)
            end
        end,
        ["brightness"] = function(direction)
            settings.brightness = changeSetting(settings.brightness, 1, 10, direction, false)  -- Brightness limited to 1-10
            print("Brightness changed to " .. settings.brightness)
        end,
        ["speed"] = function(direction)
            settings.speed = changeSetting(settings.speed, 1, 10, direction, true)  -- Speed wraps around
            print("Speed changed to " .. settings.speed)
        end
    }

    -- Validate that there are arguments and they are in pairs (flag and direction)
    if (#args - 1) % 2 ~= 0 then
        print("Error: Invalid number of arguments. Each flag must be followed by 'up' or 'down'.")
        return
    end

    -- Start at index 2, because arg[1] is the path used to run the folder
    for i = 2, #args, 2 do
        local flag = args[i]
        local direction = args[i + 1]

        -- Ensure direction is valid
        if direction == nil or (direction ~= "up" and direction ~= "down") then
            print("Error: Invalid direction for flag '" .. flag .. "'. Use 'up' or 'down'.")
            return
        end

        -- Map the flag to the actual command
        local command = flagToCommand[flag]
        if command and validCommands[command] then
            validCommands[command](direction)
            commandTriggered = true
        else
            print("Invalid flag: " .. tostring(flag))
        end
    end

    -- Save settings if any command was triggered
    if commandTriggered then
        command.run(settings, colors, tables.double_colors)  -- Run the command with updated settings
        saveSettings()  -- Save the updated settings
        
        love.event.quit()  -- Directly quit Love2D
    end
end


-- Example: handleCLIArgs({ "./love", "-m", "up", "-c", "down" })
handleCLIArgs(arg)  -- Pass the command-line arguments to the function
