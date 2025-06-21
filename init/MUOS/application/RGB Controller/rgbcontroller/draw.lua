local draw = {}
local push = require "push"
local tables = require("tables")

-- Local variables for assets and fade effect
local backgroundImage, spriteSheet
local icons = {}
local fadeAlpha = 0  -- Fade effect, fully transparent by default

-- Screen and layout variables
local screenWidth, screenHeight
local fixedVerticalSpacing = 24
local leftColumnOffsetX, rightColumnOffsetX = 110, 80
local menuStartHeight, stripYOffset = 64, 16

-- Sprite sheet details
local spriteWidth, spriteHeight = 80, 16
local numFrames = 10  -- Number of frames in the sprite sheet

-- Helper function to check if a menu option should be greyed out
local function shouldGreyOutOption(option)
    local mode = settings.mode
    if mode == 1 then
        return option ~= "Mode"
    elseif mode >= 2 and mode <= 5 then
        return not (option == "Mode" or option == "Color" or option == "Brightness")
    elseif mode == 6 then
        return not (option == "Mode" or option == "Combo" or option == "Brightness")
    elseif mode == 7 or mode == 8 then
        return not (option == "Mode" or option == "Brightness" or option == "Speed")
    end
    return false
end

-- Load assets function
function draw.load()
    windowWidth, windowHeight = love.graphics.getDimensions()

    -- Load background and sprite sheet
    backgroundImage = love.graphics.newImage("assets/sprites/background.png")
    spriteSheet = love.graphics.newImage("assets/sprites/slider.png")

    -- Load icons based on menu option names
    for _, option in ipairs(menu) do
        local iconPath = string.format("assets/sprites/%s.png", option:lower())
        icons[option] = love.graphics.newImage(iconPath)
    end
end

-- Render the menu and other elements
function draw.render()
    local bgWidth, bgHeight = backgroundImage:getDimensions()
    local scaleX, scaleY = push:getWidth() / bgWidth, push:getHeight() / bgHeight
    local scale = math.max(scaleX, scaleY)
    local offsetX, offsetY = (push:getWidth() - bgWidth * scale) / 2, (push:getHeight() - bgHeight * scale) / 2

    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.draw(backgroundImage, offsetX, offsetY, 0, scale, scale)

    local centerX = push:getWidth() / 2
    local dynamicLeftOffsetX = leftColumnOffsetX * scale
    local dynamicRightOffsetX = rightColumnOffsetX * scale
    local menuVerticalSpacing = fixedVerticalSpacing * scale
    local menuStartY = menuStartHeight * scale
    local iconSize = 16 * scale

    for i, option in ipairs(menu) do
        local yPosition = menuStartY + (i - 1) * menuVerticalSpacing
        local isGreyedOut = shouldGreyOutOption(option)

        love.graphics.setFont(isGreyedOut and fonts.greyedOut or fonts.regular)
        love.graphics.setColor(isGreyedOut and {0.5, 0.5, 0.5} or {1, 1, 1})

        if icons[option] then
            love.graphics.draw(icons[option], centerX - dynamicLeftOffsetX - iconSize - 16, yPosition, 0, scale, scale)
        end

        love.graphics.print(option, centerX - dynamicLeftOffsetX, yPosition)

        if i == currentSelection then
            local optionTextWidth = love.graphics.getFont():getWidth(option)
            local stripX = centerX - dynamicLeftOffsetX - 10
            local stripY = yPosition + stripYOffset + 16
            drawSelectionStrip(stripX, stripY, optionTextWidth + 20, 3 * scale)
        end
    end

    for i, option in ipairs(menu) do
        local yPosition = menuStartY + (i - 1) * menuVerticalSpacing
        local isGreyedOut = shouldGreyOutOption(option)
        local valueIndex = getFrameIndex(option)

        love.graphics.setFont(isGreyedOut and fonts.greyedOut or fonts.regular)
        love.graphics.setColor(isGreyedOut and {0.5, 0.5, 0.5} or {1, 1, 1})

        if option == "Brightness" or option == "Speed" then
            valueIndex = math.min(math.max(valueIndex, 1), numFrames)
            local frameX = (valueIndex - 1) * spriteWidth
            local quad = love.graphics.newQuad(frameX, 0, spriteWidth, spriteHeight, spriteSheet:getDimensions())
            love.graphics.draw(spriteSheet, quad, centerX + dynamicRightOffsetX - spriteWidth * scale / 2, yPosition, 0, scale, scale)
        else
            local valueText = getOptionValueText(option)
            love.graphics.print(valueText, centerX + dynamicRightOffsetX - love.graphics.getFont():getWidth(valueText) / 2, yPosition)
        end
    end

    if fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, push:getWidth(), push:getHeight())
        love.graphics.setColor(1, 1, 1)
    end
end

-- Helper function to draw the selection indicator strip
function drawSelectionStrip(x, y, width, height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", x + 1, y, width - 2, height / 3)
    love.graphics.rectangle("fill", x, y + 1, width, height / 3)
    love.graphics.rectangle("fill", x + 1, y + 2, width - 2, height / 3)
end

-- Get the sprite frame index for a menu option
function getFrameIndex(option)
    if option == "Brightness" then
        return settings.brightness
    elseif option == "Speed" then
        return settings.speed
    else
        return 1
    end
end

-- Get the text value for a menu option
function getOptionValueText(option)
    if option == "Mode" then
        return modes[settings.mode] or "Unknown"
    elseif option == "Color" then
        return colors[settings.color].name or "Unknown"
    elseif option == "Combo" then
        return tables.double_colors[settings.combo] and tables.double_colors[settings.combo].name or "Unknown"
    else
        return ""
    end
end

-- Set fade alpha value
function draw.setFadeAlpha(alpha)
    fadeAlpha = alpha
end

-- Set the menu starting height
function draw.setMenuStartHeight(height)
    menuStartHeight = height
end

-- Set the vertical offset for the selection strip
function draw.setStripYOffset(offset)
    stripYOffset = offset
end

return draw
