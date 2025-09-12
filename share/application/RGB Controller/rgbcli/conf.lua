function love.conf(t)
    t.console = true           -- Enable console output (useful for debugging in CLI mode)
    t.modules.window = false    -- Disable the window module
    t.modules.graphics = false  -- Disable the graphics module
    t.modules.audio = false     -- Disable audio if not needed
    t.modules.image = false     -- Disable image handling
    t.modules.mouse = false     -- Disable mouse input
    t.modules.touch = false     -- Disable touch input
    t.modules.video = false     -- Disable video module
    t.modules.thread = false    -- Disable threads if you aren't using them
    t.window = nil              -- Remove window settings, as the window is disabled
end
