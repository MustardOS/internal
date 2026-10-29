local ui = require("src.ui")
local theme = require("src.theme")
local sound = require("src.sound")

-- A yes/no dialog. opts: title, body, yes (button label), onYes.
local Confirm = { overlay = true }
Confirm.__index = Confirm

function Confirm.new(app, opts)
    return setmetatable({ app = app, t = 0, opts = opts }, Confirm)
end

function Confirm:update(dt)
    self.t = self.t + dt
end

function Confirm:busy()
    return self.t < 0.3
end

function Confirm:action(a)
    if a == "a" then
        sound.play("open")
        self.app.pop()
        if self.opts.onYes then self.opts.onYes() end
    elseif a == "b" or a == "start" then
        sound.play("close")
        self.app.pop()
    end
end

function Confirm:draw()
    local p = ui.ease(self.t / 0.14)
    local w, h = 420, 180
    local x, y = ui.card(w, h, p)
    theme.set("text", p)
    ui.text(self.opts.title, x + 32, y + 28, 26, "bold")
    theme.set("muted", p)
    ui.text(self.opts.body, x + 32, y + 70, 17, "regular", "left", w - 64)
    ui.hints({ { "B", "Cancel" }, { "A", self.opts.yes or "OK" } }, x + w - 24, y + h - 28, "right", p)
end

return Confirm
