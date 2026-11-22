-- Input handler for D-pad / keyboard controls
-- Modeled after Scrappy's helpers/input.lua

local input = {}

local joystick

-- Analog stick deadzone and release thresholds
local AXIS_DEADZONE = 0.5
local AXIS_RELEASE  = 0.3
local AXIS_DEADZONE_SQ = AXIS_DEADZONE * AXIS_DEADZONE
local AXIS_RELEASE_SQ  = AXIS_RELEASE * AXIS_RELEASE
local stick_states = setmetatable({}, { __mode = "k" })

local function get_stick_state(js)
    local st = stick_states[js]
    if not st then
        st = { x = 0, y = 0, dir = nil }
        stick_states[js] = st
    end
    return st
end

local function is_dpad_held(js, dir_event)
    if not (js and js.isGamepad and js:isGamepad() and js.isGamepadDown) then
        return false
    end
    if dir_event == input.events.LEFT then
        return js:isGamepadDown("dpleft")
    elseif dir_event == input.events.RIGHT then
        return js:isGamepadDown("dpright")
    elseif dir_event == input.events.UP then
        return js:isGamepadDown("dpup")
    elseif dir_event == input.events.DOWN then
        return js:isGamepadDown("dpdown")
    end
    return false
end

-- Hold-to-repeat configuration
local repeat_delay = 0.3    -- initial delay before auto-repeat
local repeat_rate  = 0.15   -- repeat interval while holding
local holding = {
    dir = nil,
    start_time = 0,
    started = false,
    last_fire = 0
}

-- Event queue
local event_queue = {}

local is_web = love.system.getOS() == "Web"

local is_pc = love.system.getOS() == "Windows" or love.system.getOS() == "Linux" or love.system.getOS() == "OS X"
local use_fallback = is_web or is_pc

input.events = {
    LEFT   = "left",
    RIGHT  = "right",
    UP     = "up",
    DOWN   = "down",
    CONFIRM = "return",               -- A button Enter key
    BACK   = "backspace",             -- B button
    SELECT = use_fallback and "tab" or "rshift",    -- Select button
    START  = use_fallback and "p" or "space",  -- Start button P or Space
    MENU   = "escape",                -- Physical Menu/Function button
    X      = is_web and "space" or "x", -- X button
    Y      = is_web and "c" or "y",     -- Y button
    L1     = is_web and "z" or (is_pc and "q" or "l1"),    -- Left shoulder
    R1     = is_web and "x" or (is_pc and "e" or "r1"),    -- Right shoulder
}

input.state = {}

input.joystick_mapping = {
    ["dpleft"]    = input.events.LEFT,
    ["dpright"]   = input.events.RIGHT,
    ["dpup"]      = input.events.UP,
    ["dpdown"]    = input.events.DOWN,
    ["a"]         = input.events.CONFIRM,
    ["b"]         = input.events.BACK,
    ["x"]         = input.events.X,
    ["y"]         = input.events.Y,
    ["back"]      = input.events.SELECT,
    ["start"]     = input.events.START,
    ["guide"]     = input.events.MENU,
    ["leftshoulder"] = input.events.L1,
    ["rightshoulder"] = input.events.R1,
}

-- Cooldown to prevent accidental double-inputs
local cooldown_duration = 0.12
local last_trigger_time = -cooldown_duration

local function can_trigger()
    local now = love.timer.getTime()
    if now - last_trigger_time >= cooldown_duration then
        last_trigger_time = now
        return true
    end
    return false
end

local function emit(event, bypass)
    if bypass or can_trigger() then
        table.insert(event_queue, event)
    end
end

input.emit = emit

function input.load()
    if love.joystick then
        local joysticks = love.joystick.getJoysticks()
        if #joysticks > 0 then
            joystick = joysticks[1]
        else
            joystick = nil
        end
    end
end

function input.getJoystick()
    return joystick
end

function input.getJoysticks()
    if love.joystick then
        return love.joystick.getJoysticks()
    end
    return {}
end

function input.update(dt)
    -- Process hold-to-repeat for directional events
    if holding.dir then
        local now = love.timer.getTime()
        if not holding.started then
            if now - holding.start_time >= repeat_delay then
                holding.started = true
                holding.last_fire = now
                emit(holding.dir, true)
            end
        else
            if now - holding.last_fire >= repeat_rate then
                holding.last_fire = now
                emit(holding.dir, true)
            end
        end
    end
end

-- Process all queued events via callback
function input.processEvents(callback)
    for _, event in ipairs(event_queue) do
        callback(event)
    end
    event_queue = {}
end

-- Check if a direction is being held
local function is_directional(event)
    return event == input.events.LEFT or event == input.events.RIGHT
        or event == input.events.UP or event == input.events.DOWN
end

function love.keypressed(key)
    local triggered = false
    for event_name, k in pairs(input.events) do
        if key == k then
            input.state[key] = true
            input.state[k] = true
            emit(k, false)
            triggered = true
        end
    end

    -- Back key bindings for PC and Web
    if not triggered and use_fallback then
        if key == "backspace" or key == "b" then
            local k = input.events.BACK
            input.state["backspace"] = true
            input.state["b"] = true
            input.state[k] = true
            emit(k, false)
            triggered = true
        end
    end

    -- Select key fallbacks
    if not triggered and use_fallback then
        if key == "tab" or key == "rshift" or key == "lshift" or key == "v" or key == "s" then
            local k = input.events.SELECT
            input.state[key] = true
            input.state[k] = true
            emit(k, false)
            triggered = true
        end
    end

    -- Start key fallbacks
    if not triggered and use_fallback then
        if key == "p" or key == "space" then
            local k = input.events.START
            input.state[key] = true
            input.state[k] = true
            emit(k, false)
            triggered = true
        end
    end

    if is_directional(key) then
        holding.dir = key
        holding.start_time = love.timer.getTime()
        holding.started = false
        holding.last_fire = holding.start_time
    end
end

function love.keyreleased(key)
    input.state[key] = false

    for _, k in pairs(input.events) do
        if key == k then
            input.state[k] = false
        end
    end

    if use_fallback then
        if key == "backspace" or key == "b" then
            local k = input.events.BACK
            input.state["backspace"] = false
            input.state["b"] = false
            input.state[k] = false
        elseif key == "tab" or key == "rshift" or key == "lshift" or key == "v" or key == "s" then
            local k = input.events.SELECT
            input.state["tab"] = false
            input.state["rshift"] = false
            input.state["lshift"] = false
            input.state["v"] = false
            input.state["s"] = false
            input.state[k] = false
        elseif key == "p" or key == "space" then
            local k = input.events.START
            input.state["p"] = false
            input.state["space"] = false
            input.state[k] = false
        end
    end

    if key == holding.dir then
        holding.dir = nil
        holding.started = false
    end

    if _G.appState == "DINO" then
        local dg = package.loaded["dino_game"]
        if dg and dg.keyreleased then
            dg.keyreleased(key)
        end
    end
end

function love.gamepadpressed(js, button)
    local event = input.joystick_mapping[button]
    if event then
        input.state[event] = true
        emit(event, false)

        if is_directional(event) then
            holding.dir = event
            holding.start_time = love.timer.getTime()
            holding.started = false
            holding.last_fire = holding.start_time
        end
    end
end

function love.gamepadreleased(js, button)
    local event = input.joystick_mapping[button]
    if event then
        local still_held = false
        if stick_states[js] and stick_states[js].dir == event then
            still_held = true
        end
        if not still_held then
            input.state[event] = false
        end
        if event == holding.dir then
            if not still_held then
                holding.dir = nil
                holding.started = false
            end
        end
    end

    if _G.appState == "DINO" then
        local dg = package.loaded["dino_game"]
        if dg and dg.gamepadreleased then
            dg.gamepadreleased(button)
        end
    end
end

-- Analog stick navigation and hold to repeat
function love.gamepadaxis(js, axis, value)
    if not js then return end
    if axis ~= "leftx" and axis ~= "lefty" then return end

    local st = get_stick_state(js)
    if axis == "leftx" then
        st.x = value
    elseif axis == "lefty" then
        st.y = value
    end

    local x = st.x
    local y = st.y
    local mag_sq = x * x + y * y

    if mag_sq >= AXIS_DEADZONE_SQ then
        if _G.controls_help == "auto" then
            _G.input_mode = "gamepad"
            if renderer and renderer.checkControlModeChange then
                renderer.checkControlModeChange()
            end
        end

        local new_dir
        if math.abs(x) >= math.abs(y) then
            if x > 0 then
                new_dir = input.events.RIGHT
            else
                new_dir = input.events.LEFT
            end
        else
            if y < 0 then
                new_dir = input.events.UP
            else
                new_dir = input.events.DOWN
            end
        end

        if st.dir ~= new_dir then
            if st.dir then
                local old_dir = st.dir
                st.dir = nil
                if not is_dpad_held(js, old_dir) then
                    input.state[old_dir] = false
                    if holding.dir == old_dir then
                        holding.dir = nil
                        holding.started = false
                    end
                end
                if _G.appState == "DINO" then
                    local dg = package.loaded["dino_game"]
                    if dg and dg.keyreleased then
                        dg.keyreleased(old_dir)
                    end
                end
            end

            st.dir = new_dir
            input.state[new_dir] = true
            emit(new_dir, false)

            if is_directional(new_dir) then
                holding.dir = new_dir
                holding.start_time = love.timer.getTime()
                holding.started = false
                holding.last_fire = holding.start_time
            end
        end
    elseif mag_sq <= AXIS_RELEASE_SQ then
        if st.dir then
            local old_dir = st.dir
            st.dir = nil
            if not is_dpad_held(js, old_dir) then
                input.state[old_dir] = false
                if holding.dir == old_dir then
                    holding.dir = nil
                    holding.started = false
                end
            end
            if _G.appState == "DINO" then
                local dg = package.loaded["dino_game"]
                if dg and dg.keyreleased then
                    dg.keyreleased(old_dir)
                end
            end
        end
    end
end

-- Controller connection and disconnection callbacks
function love.joystickadded(js)
    input.load()
    if js then
        stick_states[js] = { x = 0, y = 0, dir = nil }
    end

    if _G.controls_help == "auto" then
        _G.input_mode = "gamepad"
        if renderer and renderer.checkControlModeChange then
            renderer.checkControlModeChange()
        end
    end

    if renderer and renderer.showToast and love.timer and (love.timer.getTime() > 2.0) then
        local name = js and js.getName and js:getName()
        if name and #name > 0 then
            renderer.showToast("Controller Connected: " .. name)
        else
            renderer.showToast("Controller Connected")
        end
    end
end

function love.joystickremoved(js)
    if js and js.isVibrationSupported and js:isVibrationSupported() then
        pcall(function() js:setVibration(0, 0) end)
    end

    if stick_states[js] then
        local old_dir = stick_states[js].dir
        if old_dir then
            input.state[old_dir] = false
            if holding.dir == old_dir then
                holding.dir = nil
                holding.started = false
            end
            if _G.appState == "DINO" then
                local dg = package.loaded["dino_game"]
                if dg and dg.keyreleased then
                    dg.keyreleased(old_dir)
                end
            end
        end
        stick_states[js] = nil
    end

    input.load()

    local joysticks = love.joystick and love.joystick.getJoysticks() or {}
    if #joysticks == 0 and _G.controls_help == "auto" then
        _G.input_mode = "keyboard"
        if renderer and renderer.checkControlModeChange then
            renderer.checkControlModeChange()
        end
    end

    if renderer and renderer.showToast and love.timer and (love.timer.getTime() > 2.0) then
        renderer.showToast("Controller Disconnected")
    end

    if #joysticks == 0 and _G.appState == "GAME" and _G.game then
        local g = _G.game
        if g.state == 0 or g.state == 3 then
            if renderer and renderer.openPause then
                renderer.openPause()
            end
            g:togglePause()
        end
    end
end

-- Touch tracking
local active_touch_id = nil
local touch_start_x = 0
local touch_start_y = 0
local touch_start_time = 0

function love.touchpressed(id, x, y, dx, dy, pressure)
    if _G.is_console_active and _G.is_console_active() then
        _G.android_console.touchpressed(id, x, y, dx, dy, pressure)
        return
    end
    if _G.appState == "DINO" then return end
    -- Only track the first finger to avoid multi-touch confusion
    if not active_touch_id then
        local w, h = love.graphics.getDimensions()
        local nav_margin = math.max(math.floor(h * 0.075), 50)
        local status_margin = 0
        pcall(function()
            if love.window and love.window.getSafeArea then
                local _, sy = love.window.getSafeArea()
                if sy and sy > 0 then status_margin = sy end
            end
        end)
        status_margin = math.max(status_margin, math.max(math.floor(h * 0.05), math.floor(32 * (w / 390)), 28))
        if y > status_margin and y < h - nav_margin then
            active_touch_id = id
            touch_start_x = x
            touch_start_y = y
            touch_start_time = love.timer.getTime()
        end
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    if _G.is_console_active and _G.is_console_active() then
        _G.android_console.touchreleased(id, x, y, dx, dy, pressure)
        return
    end
    if _G.appState == "DINO" then return end
    if active_touch_id ~= id then return end
    active_touch_id = nil

    -- Calculate distance and duration
    local end_time = love.timer.getTime()
    local duration = end_time - touch_start_time
    local diff_x = x - touch_start_x
    local diff_y = y - touch_start_y
    local abs_x = math.abs(diff_x)
    local abs_y = math.abs(diff_y)

    local w, h = love.graphics.getDimensions()
    local min_dim = math.min(w, h)
    local scale = math.max(1.0, min_dim / 390)
    local swipe_threshold = math.max(48, math.floor(42 * scale))
    local tap_threshold = math.floor(swipe_threshold * 0.45)

    if abs_x > swipe_threshold or abs_y > swipe_threshold then
        -- D-Pad swipe gesture
        if abs_x > abs_y then
            if diff_x > 0 then emit(input.events.RIGHT, false)
            else emit(input.events.LEFT, false) end
        else
            if diff_y > 0 then emit(input.events.DOWN, false)
            else emit(input.events.UP, false) end
        end
    elseif abs_x < tap_threshold and abs_y < tap_threshold then
        -- It's a tap
        if _G.appState == "STORE" and _G.store_sort_btn_bounds then
            local b = _G.store_sort_btn_bounds
            if x >= b.x and x <= (b.x + b.w) and y >= b.y and y <= (b.y + b.h) then
                if _G.cycleStoreSortMode then
                    _G.cycleStoreSortMode()
                    return
                end
            end
        end

        local w, h = love.graphics.getDimensions()
        if y < h * 0.2 then
            -- Top 20% of screen
            if duration > 0.4 then
                -- Theme toggle shortcut
                emit(input.events.Y, false)
            else
                if x < w * 0.5 then
                    -- Back shortcut
                    emit(input.events.BACK, false)
                else
                    -- Pause shortcut
                    emit(input.events.START, false)
                end
            end
        else
            -- Bottom 80% of screen
            if duration > 0.4 then
                if x < w * 0.5 then
                    -- Swap powerup shortcut
                    emit(input.events.L1, false)
                else
                    -- Bomb powerup shortcut
                    emit(input.events.R1, false)
                end
            else
                -- Confirm shortcut
                emit(input.events.CONFIRM, false)
            end
        end
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if _G.is_console_active and _G.is_console_active() then
        _G.android_console.touchmoved(id, x, y, dx, dy, pressure)
        return
    end
    if _G.appState == "DINO" then return end
end

return input
