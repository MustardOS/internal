local ui = require("src.ui")
local theme = require("src.theme")
local sound = require("src.sound")

local Settings = {}
Settings.__index = Settings

local ROWS = {
    { key = "theme", label = "Theme", about = "Light themes: Paper, Sakura, Frankfurt, Solarized Light. Dark: Cyanotype, Solarized Dark, Nord, Gruvbox, and Chalkboard with chalk dust and a wooden frame." },
    { key = "mistakes", label = "Check mistakes", about = "Wrong numbers turn red and are counted." },
    { key = "matching", label = "Highlight matching numbers", about = "Cells and notes with the selected number light up." },
    { key = "autoclear", label = "Clear notes automatically", about = "Placing a number removes it from notes in the same row, column and box." },
    { key = "hints", label = "Hints",
      choices = { { "off", "Off" }, { "explained", "Explained" }, { "instant", "Instant" } },
      about = "Off hides the hint button. Explained shows which technique to use next and why. Instant reveals a number straight away." },
    { key = "timer", label = "Show timer", about = "The clock still runs when hidden, so best times stay fair." },
    { key = "sound", label = "Sound effects", about = "Clicks and chimes as you play." },
    { key = "generator", label = "Puzzle generator",
      choices = { { "classic", "Classic" }, { "dlx", "Dancing Links" } },
      about = "Both make puzzles with exactly one solution, graded the same way. Classic uses a backtracking solver, Dancing Links uses Knuth's Algorithm X." },
}

function Settings.new(app)
    return setmetatable({ app = app, t = 0, sel = 1 }, Settings)
end

function Settings:update(dt)
    self.t = self.t + dt
end

function Settings:change(dir)
    local s = self.app.settings
    local row = ROWS[self.sel]
    if row.key == "theme" then
        local idx = 1
        for k, key in ipairs(theme.ORDER) do
            if key == s.theme then idx = k end
        end
        idx = (idx - 1 + dir) % #theme.ORDER + 1
        s.theme = theme.ORDER[idx]
    elseif row.choices then
        local idx = 1
        for k, c in ipairs(row.choices) do
            if c[1] == s[row.key] then idx = k end
        end
        idx = (idx - 1 + dir) % #row.choices + 1
        s[row.key] = row.choices[idx][1]
    else
        s[row.key] = not s[row.key]
    end
    self.app.applySettings()
    self.app.saveSettings()
    sound.play("note")
end

function Settings:action(a)
    if a == "up" then
        self.sel = (self.sel - 2) % #ROWS + 1
        sound.play("menu")
    elseif a == "down" then
        self.sel = self.sel % #ROWS + 1
        sound.play("menu")
    elseif a == "left" then
        self:change(-1)
    elseif a == "right" or a == "a" then
        self:change(1)
    elseif a == "b" or a == "start" then
        sound.play("close")
        self.app.pop()
    end
end

function Settings:value(row)
    local v = self.app.settings[row.key]
    if row.key == "theme" then return theme.name(v) end
    if row.choices then
        for _, c in ipairs(row.choices) do
            if c[1] == v then return c[2] end
        end
    end
    return v and "On" or "Off"
end

function Settings:draw()
    theme.set("text")
    ui.text("Settings", 64, 40, 36, "bold")

    local x, w, y0, h = 64, 592, 92, 36
    for k, row in ipairs(ROWS) do
        local cy = y0 + (k - 1) * h + h / 2
        local selected = (k == self.sel)
        if selected then
            theme.set("panel")
            ui.rect("fill", x - 16, cy - h / 2 + 3, w + 32, h - 6, 8)
            theme.set("accent")
            ui.rect("fill", x - 16, cy - 10, 4, 20, 2)
        end
        theme.set(selected and "text" or "muted")
        ui.centered(row.label, x, cy, 20, selected and "bold" or "regular", "left")

        local value = self:value(row)
        local current = self.app.settings[row.key]
        local on = (row.key == "theme") or (row.choices and current ~= "off") or (not row.choices and current)
        theme.set(on and (selected and "mark" or "text") or "muted")
        local vw = ui.centered(value, x + w - 22, cy, 20, "bold", "right")
        if selected then
            theme.set("muted")
            ui.centered("<", x + w - 22 - vw - 16, cy, 18, "bold", "center")
            ui.centered(">", x + w - 6, cy, 18, "bold", "center")
        end
    end

    theme.set("muted")
    ui.text(ROWS[self.sel].about, x, y0 + #ROWS * h + 14, 16, "regular", "left", w)

    ui.hints({ { "B", "Back" }, { "A", "Change" } }, 696, 452, "right")
end

return Settings
