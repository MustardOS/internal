local command = require("command")
local tables = require("tables")
local input = require("input")
local draw = require("draw")
local splashlib = require("splash")
local soundmanager = require("soundmanager")
local push = require "push"
love.graphics.setDefaultFilter("nearest", "nearest")
local gameWidth, gameHeight = 640, 480 -- Fixed game resolution
local windowWidth, windowHeight = love.window.getDesktopDimensions()
--windowHeight = 1280 -- Uncomment this when using on desktop to show windows
--windowWidth = 1280
push:setupScreen(gameWidth, gameHeight, windowWidth, windowHeight, {fullscreen = false})

currentSelection = 1

-- Access the modes, colors, settings, and menu from the tables module
modes = tables.modes
colors = tables.colors
settings = tables.settings
menu = tables.menu

-- Fade variables
local fadeDuration = 0.4 -- Duration of the fade
local fadeTimer = 0
local fading = false

function love.load()
    -- Initialize sound manager
    soundmanager.load()
    setupFont()
    
    -- Initialize the splash screen
    splash = splashlib()
    splash.onDone = function() --Splash is done, continue loading the game
        splash = nil  -- Set splash to nil to stop drawing it
        loadSettings()
        screenWidth, screenHeight = love.graphics.getDimensions()
        command.run(settings, colors, tables.double_colors)
        input.load()
        draw.load()
        fading = true  -- Start the fade effect
    end
end

function love.update(dt)
    if splash then
        splash:update(dt)
    else
        input.update(dt)
        
        if fading then
            fadeTimer = fadeTimer + dt
            if fadeTimer >= fadeDuration then
                fadeTimer = fadeDuration
                fading = false
            end
        end
    end
end

-- Function to fade in the app
function love.draw()
    push:start() 
    if splash then
        splash:draw()
    else
        draw.render()

        -- Apply the fade effect if fading is active
        if fading then
            local fadeAlpha = 1 - (fadeTimer / fadeDuration)
            love.graphics.setColor(0, 0, 0, fadeAlpha)
            love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)
        end

        -- Reset color to white after drawing
        love.graphics.setColor(1, 1, 1)
    end
    push:finish()
end


-- Function to set up the fonts based on the screen height
function setupFont()

	love.graphics.setDefaultFilter("nearest", "nearest")
    -- Calculate the font size as a percentage of the screen height
    fontSize = 32 -- % of the screen height
    
    -- Create the main font with the calculated size
    customFont = love.graphics.newFont("assets/fonts/Peaberry-Base.otf", fontSize)
	customFont:setFilter("nearest", "nearest")
    
    -- Create a greyed-out version of the font 
    greyedOutFont = love.graphics.newFont("assets/fonts/Peaberry-Base.otf", fontSize)
	greyedOutFont:setFilter("nearest", "nearest")
    

    smallFont = love.graphics.newFont("assets/fonts/Peaberry-Base.otf", 16)
    -- Store both fonts in a table for easy access
    fonts = {
        regular = customFont,
        greyedOut = greyedOutFont,
        small = smallFont
    }
	
	
end

function saveSettings()
    local settingsData = string.format(
        "mode=%d\ncolor=%d\ncombo=%d\nbrightness=%d\nspeed=%d",
        settings.mode,
        settings.color,
        settings.combo,
        settings.brightness,
        settings.speed
    )
    
    -- Specify the absolute file path
    local filePath = "/run/muos/storage/theme/active/rgb/settings.txt"
    
    -- Use Lua's standard I/O library to write the file
    local file = io.open(filePath, "w")
    
    if file then
        file:write(settingsData)
        file:close()
    else
        print("Failed to open file for writing.")
    end
end


function loadSettings()
    -- Specify the absolute file path
    local filePath = "/run/muos/storage/theme/active/rgb/settings.txt"
    
    -- Use Lua's standard I/O library to read the file
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


-- Parse the settings content from a file
function parseSettings(contents)
    for line in contents:gmatch("[^\r\n]+") do
        local key, value = line:match("(%w+)=(%d+)")
        if key and value then
            settings[key] = tonumber(value)
        end
    end
end

-- Convert brightness from 1-10 to 0-255 scale
function convertBrightness(brightness)
    return math.floor((brightness - 1) * 25.5)
end
