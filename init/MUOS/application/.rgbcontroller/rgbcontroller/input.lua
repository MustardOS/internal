local input = {}

local inputCooldown = 0.2
local timeSinceLastInput = 0
local joystick

-- Require the command and soundmanager modules
local command = require("command")
local soundmanager = require("soundmanager")
local tables = require("tables")

function input.load()
    -- Initialize joystick
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        joystick = joysticks[1]
    end

    -- Load sound effects
    soundmanager.load()
end

function input.update(dt)
    -- Update the timer
    timeSinceLastInput = timeSinceLastInput + dt

    if joystick then
        handleJoystickInput(dt)
    end
end

function handleJoystickInput(dt)
    if timeSinceLastInput >= inputCooldown then
        local changed = false
        local settingChanged = false
        local commandTriggered = false

           -- Determine which menu items are selectable based on settings.mode
           local selectableIndices = {}
           if settings.mode == 1 then  -- Off
            selectableIndices = {1}  -- Mode
           elseif settings.mode == 2 then  -- Solid Color
               selectableIndices = {1, 2, 4}  -- Mode, Color, Brightness
           elseif settings.mode >= 3 and settings.mode <= 5 then  -- Fast, Med, Slow Breathing
               selectableIndices = {1, 2, 4}  -- Mode, Color, Brightness
           elseif settings.mode == 6 then  -- Double Static
               selectableIndices = {1, 3, 4}  -- Mode, Combo, Brightness
           elseif settings.mode >= 7 and settings.mode <= 8 then  -- Mono Rainbow, Multi Rainbow
               selectableIndices = {1, 4, 5}  -- Mode, Brightness, Speed
           else
               -- No restriction for other modes
               selectableIndices = {1, 2, 3, 4, 5}  -- All options available
           end

        -- Ensure the current selection is valid based on the selectable indices
        if not tableContains(selectableIndices, currentSelection) then
            currentSelection = selectableIndices[1]
        end

        -- Check for quit command (LB + RB)
        if joystick:isGamepadDown("leftshoulder") and joystick:isGamepadDown("rightshoulder") then
            love.event.quit()  -- Quit 
            return
        end

        -- Navigate through the menu using D-pad up and down
        if joystick:isGamepadDown("dpup") then
            currentSelection = currentSelection - 1
            -- Wrap around if needed, considering selectable items
            while not tableContains(selectableIndices, currentSelection) do
                currentSelection = currentSelection - 1
                if currentSelection < 1 then 
                    currentSelection = #menu 
                end
            end
            changed = true
            soundmanager.playUp()  -- Play the "up" sound
        elseif joystick:isGamepadDown("dpdown") then
            currentSelection = currentSelection + 1
            -- Wrap around if needed, considering selectable items
            while not tableContains(selectableIndices, currentSelection) do
                currentSelection = currentSelection + 1
                if currentSelection > #menu then 
                    currentSelection = 1 
                end
            end
            changed = true
            soundmanager.playDown()  -- Play the "down" sound
        end

        -- Adjust settings based on D-pad left and right
        if joystick:isGamepadDown("dpleft") or joystick:isGamepadDown("dpright") then
            -- Determine the adjustment value
            local adjustValue = joystick:isGamepadDown("dpright") and 1 or -1

            -- Change settings based on current selection
            if menu[currentSelection] == "Mode" then
                settings.mode = settings.mode + adjustValue
                if settings.mode < 1 then settings.mode = #modes end
                if settings.mode > #modes then settings.mode = 1 end
                settingChanged = true
                soundmanager.playLeft()  -- Play the "left" sound
            elseif menu[currentSelection] == "Color" then
                settings.color = settings.color + adjustValue
                if settings.color < 1 then settings.color = #colors end
                if settings.color > #colors then settings.color = 1 end
                settingChanged = true
                soundmanager.playRight()  -- Play the "right" sound
            elseif menu[currentSelection] == "Combo" then
                settings.combo = settings.combo + adjustValue
                if settings.combo < 1 then settings.combo = #tables.double_colors end
                if settings.combo > #tables.double_colors then settings.combo = 1 end
                settingChanged = true
                soundmanager.playRight()  -- Play the "right" sound
            elseif menu[currentSelection] == "Brightness" then
                settings.brightness = settings.brightness + adjustValue
                if settings.brightness < 1 then settings.brightness = 1 end
                if settings.brightness > 10 then settings.brightness = 10 end
                settingChanged = true
                soundmanager.playRight()  -- Play the "right" sound
            elseif menu[currentSelection] == "Speed" then
                settings.speed = settings.speed + adjustValue
                if settings.speed < 1 then settings.speed = 1 end
                if settings.speed > 10 then settings.speed = 10 end
                settingChanged = true
                soundmanager.playRight()  -- Play the "right" sound
            end

            -- Save settings if something changed
            if settingChanged then
                saveSettings()
                commandTriggered = true
            end
        end

        -- Run command and reset cooldown if a command was triggered
        if commandTriggered or changed then
            if commandTriggered then
                command.run(settings, colors, tables.double_colors)
            end
            timeSinceLastInput = 0  -- Reset the cooldown timer
        end
    end
end

-- Utility function to check if a value is in a table
function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end


return input