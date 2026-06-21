--[[
    Obfuscated UI Library for Matcha
    Exported functions: p:W(title, pos, size) -> Window
    Window:T(name) -> Tab
    Tab:B(text, cb) -> Button, Tg(text, def, cb) -> Toggle, S(text, min, max, def, cb) -> Slider, L(text) -> Label
]]

local a = game:GetService("Players")
local b = game:GetService("UserInputService")
local c = game:GetService("RunService")
local d = a.LocalPlayer:GetMouse()
local e = Drawing.Fonts

local function f(t, pr)
    local o = Drawing.new(t)
    for k, v in pairs(pr) do o[k] = v end
    return o
end

local function g(v, mn, mx)
    return math.max(mn, math.min(mx, v))
end

local h = {}
h.__index = h

function h:R()
    for _, o in ipairs(self.d) do o:Remove() end
end
function h:V(v)
    for _, o in ipairs(self.d) do o.Visible = v end
end
function h:IS(cl)
    return getmetatable(self) == cl
end

-- Button (i)
local i = setmetatable({}, h)
i.__index = i

function i.new(tab, txt, cb)
    local s = setmetatable({}, i)
    s.t = tab; s.tx = txt; s.cb = cb
    s.p = Vector2.new(0, 0)
    s.sz = Vector2.new(tab.W.CS.X - 20, 24)
    s.d = {}
    local bg = f("Square", { Color = Color3.fromRGB(50, 50, 50), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 2, Filled = true })
    local lb = f("Text", { Text = txt, Color = Color3.fromRGB(255, 255, 255), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 3, Font = e, Size = 14, Center = true, Outline = false })
    table.insert(s.d, bg); table.insert(s.d, lb)
    s.bg = bg; s.lb = lb
    return s
end

function i:U(x, y)
    self.bg.Position = Vector2.new(x + self.p.X, y + self.p.Y)
    self.bg.Size = self.sz
    self.lb.Position = self.bg.Position + self.sz / 2
    self.lb.Text = self.tx
end

function i:H(m)
    local ps = self.bg.Position
    local sz = self.bg.Size
    return m.X >= ps.X and m.X <= ps.X + sz.X and m.Y >= ps.Y and m.Y <= ps.Y + sz.Y
end

function i:O()
    if self.cb then self.cb() end
end

-- Toggle (j)
local j = setmetatable({}, h)
j.__index = j

function j.new(tab, txt, def, cb)
    local s = setmetatable({}, j)
    s.t = tab; s.tx = txt; s.st = def or false; s.cb = cb
    s.p = Vector2.new(0, 0)
    s.sz = Vector2.new(tab.W.CS.X - 20, 24)
    s.d = {}
    local bg = f("Square", { Color = Color3.fromRGB(40, 40, 40), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 2, Filled = true })
    local lb = f("Text", { Text = txt, Color = Color3.fromRGB(255, 255, 255), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 3, Font = e, Size = 14, Center = false, Outline = false })
    local ind = f("Square", { Color = s.st and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(100, 100, 100), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 4, Filled = true, Size = Vector2.new(16, 16) })
    table.insert(s.d, bg); table.insert(s.d, lb); table.insert(s.d, ind)
    s.bg = bg; s.lb = lb; s.ind = ind
    return s
end

function j:U(x, y)
    self.bg.Position = Vector2.new(x + self.p.X, y + self.p.Y)
    self.bg.Size = self.sz
    self.lb.Position = Vector2.new(x + self.p.X + 5, y + self.p.Y + 4)
    self.ind.Position = Vector2.new(x + self.p.X + self.sz.X - 25, y + self.p.Y + 4)
    self.ind.Color = self.st and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(100, 100, 100)
end

function j:H(m)
    local ps = self.bg.Position
    local sz = self.bg.Size
    return m.X >= ps.X and m.X <= ps.X + sz.X and m.Y >= ps.Y and m.Y <= ps.Y + sz.Y
end

function j:O()
    self.st = not self.st
    if self.cb then self.cb(self.st) end
end

-- Slider (m)
local m = setmetatable({}, h)
m.__index = m

function m.new(tab, txt, mn, mx, def, cb)
    local s = setmetatable({}, m)
    s.t = tab; s.tx = txt; s.mn = mn; s.mx = mx
    s.val = g(def, mn, mx); s.cb = cb
    s.p = Vector2.new(0, 0)
    s.sz = Vector2.new(tab.W.CS.X - 20, 30)
    s.d = {}; s.dr = false
    local bg = f("Square", { Color = Color3.fromRGB(40, 40, 40), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 2, Filled = true })
    local lb = f("Text", { Text = txt .. ": " .. tostring(s.val), Color = Color3.fromRGB(255, 255, 255), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 3, Font = e, Size = 13, Center = false, Outline = false })
    local tk = f("Square", { Color = Color3.fromRGB(70, 70, 70), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 2, Filled = true, Size = Vector2.new(s.sz.X - 20, 4) })
    local fl = f("Square", { Color = Color3.fromRGB(0, 170, 255), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 3, Filled = true })
    local kn = f("Square", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 4, Filled = true, Size = Vector2.new(10, 16) })
    table.insert(s.d, bg); table.insert(s.d, lb); table.insert(s.d, tk); table.insert(s.d, fl); table.insert(s.d, kn)
    s.bg = bg; s.lb = lb; s.tk = tk; s.fl = fl; s.kn = kn
    return s
end

function m:U(x, y)
    self.bg.Position = Vector2.new(x + self.p.X, y + self.p.Y)
    self.bg.Size = self.sz
    self.lb.Position = Vector2.new(x + self.p.X + 5, y + self.p.Y + 2)
    local ty = y + self.p.Y + 18
    self.tk.Position = Vector2.new(x + self.p.X + 10, ty)
    local r = (self.val - self.mn) / (self.mx - self.mn)
    local fw = r * (self.tk.Size.X - 2)
    self.fl.Position = self.tk.Position + Vector2.new(1, 1)
    self.fl.Size = Vector2.new(fw, self.tk.Size.Y - 2)
    self.kn.Position = Vector2.new(self.tk.Position.X + r * self.tk.Size.X - self.kn.Size.X / 2, ty - 6)
    self.lb.Text = self.tx .. ": " .. tostring(self.val)
end

function m:H(m)
    local ps = self.bg.Position
    local sz = self.bg.Size
    return m.X >= ps.X and m.X <= ps.X + sz.X and m.Y >= ps.Y and m.Y <= ps.Y + sz.Y
end

function m:UM(mx)
    local ts = self.tk.Position.X
    local r = g((mx - ts) / self.tk.Size.X, 0, 1)
    self.val = math.floor(self.mn + (self.mx - self.mn) * r + 0.5)
    if self.cb then self.cb(self.val) end
end

-- Label (k)
local k = setmetatable({}, h)
k.__index = k

function k.new(tab, txt)
    local s = setmetatable({}, k)
    s.t = tab; s.tx = txt
    s.p = Vector2.new(0, 0)
    s.sz = Vector2.new(tab.W.CS.X - 20, 18)
    s.d = {}
    local lb = f("Text", { Text = txt, Color = Color3.fromRGB(200, 200, 200), Transparency = 0, Visible = false, ZIndex = tab.W.Z + 3, Font = e, Size = 13, Center = false, Outline = false })
    table.insert(s.d, lb)
    s.lb = lb
    return s
end

function k:U(x, y)
    self.lb.Position = Vector2.new(x + self.p.X + 5, y + self.p.Y + 2)
    self.lb.Text = self.tx
end

function k:H(m)
    return false
end

-- Tab (l)
local l = {}
l.__index = l

function l.new(win, nm)
    local s = setmetatable({}, l)
    s.W = win; s.N = nm
    s.els = {}; s.act = false; s.tbBtn = nil
    return s
end

function l:AE(e)
    table.insert(self.els, e)
    self.W:RFL()
    return e
end

function l:B(txt, cb) return self:AE(i.new(self, txt, cb)) end
function l:Tg(txt, def, cb) return self:AE(j.new(self, txt, def, cb)) end
function l:S(txt, mn, mx, def, cb) return self:AE(m.new(self, txt, mn, mx, def, cb)) end
function l:L(txt) return self:AE(k.new(self, txt)) end

-- Window (n)
local n = {}
local wZC = 10
n.__index = n

function n.new(lib, title, pos, size)
    local s = setmetatable({}, n)
    s.Lib = lib; s.Title = title
    s.Pos = pos or Vector2.new(200, 200)
    s.Size = size or Vector2.new(400, 300)
    s.Z = wZC; wZC = wZC + 20
    s.CS = s.Size - Vector2.new(20, 55)
    s.Tabs = {}; s.ATab = nil
    s.dr = false; s.DragOff = Vector2.new(0, 0); s.Vis = true

    s.BG = f("Square", { Color = Color3.fromRGB(30, 30, 30), Transparency = 0, Visible = true, ZIndex = s.Z, Filled = true, Size = s.Size, Position = s.Pos })
    s.TitleBar = f("Square", { Color = Color3.fromRGB(40, 40, 40), Transparency = 0, Visible = true, ZIndex = s.Z + 1, Filled = true, Size = Vector2.new(s.Size.X, 25), Position = s.Pos })
    s.TitleText = f("Text", { Text = title, Color = Color3.fromRGB(255, 255, 255), Transparency = 0, Visible = true, ZIndex = s.Z + 2, Font = e, Size = 14, Center = false, Outline = false, Position = s.Pos + Vector2.new(5, 4) })
    s.CloseBtn = f("Text", { Text = "X", Color = Color3.fromRGB(255, 100, 100), Transparency = 0, Visible = true, ZIndex = s.Z + 3, Font = e, Size = 16, Center = true, Outline = false, Position = s.Pos + Vector2.new(s.Size.X - 15, 5) })
    s.WDraws = {s.BG, s.TitleBar, s.TitleText, s.CloseBtn}
    s.TButtons = {}
    table.insert(lib.Windows, s)
    return s
end

function n:T(nm)
    local tab = l.new(self, nm)
    table.insert(self.Tabs, tab)
    local bg = f("Square", { Color = Color3.fromRGB(50, 50, 50), Transparency = 0, Visible = false, ZIndex = self.Z + 1, Filled = true })
    local txt = f("Text", { Text = nm, Color = Color3.fromRGB(255, 255, 255), Transparency = 0, Visible = false, ZIndex = self.Z + 2, Font = e, Size = 13, Center = true, Outline = false })
    tab.tbBtn = {BG = bg, Text = txt}
    table.insert(self.TButtons, tab.tbBtn)
    if #self.Tabs == 1 then self:SAT(tab) end
    self:RFL()
    return tab
end

function n:SAT(tab)
    if self.ATab == tab then return end
    if self.ATab then
        for _, e in ipairs(self.ATab.els) do e:V(false) end
        if self.ATab.tbBtn then
            self.ATab.tbBtn.BG.Visible = false
            self.ATab.tbBtn.Text.Visible = false
        end
    end
    self.ATab = tab
    if tab then
        for _, e in ipairs(tab.els) do e:V(true) end
        if tab.tbBtn then
            tab.tbBtn.BG.Visible = true
            tab.tbBtn.Text.Visible = true
            tab.tbBtn.BG.Color = Color3.fromRGB(60, 60, 60)
        end
    end
    self:RFL()
end

function n:RFL()
    self.BG.Size = self.Size; self.BG.Position = self.Pos
    self.TitleBar.Size = Vector2.new(self.Size.X, 25); self.TitleBar.Position = self.Pos
    self.TitleText.Position = self.Pos + Vector2.new(5, 4)
    self.CloseBtn.Position = self.Pos + Vector2.new(self.Size.X - 15, 5)
    local tx = self.Pos.X + 10
    local ty = self.Pos.Y + 28
    local tw = 60; local sp = 2
    for i, tab in ipairs(self.Tabs) do
        local btn = tab.tbBtn
        if btn then
            btn.BG.Size = Vector2.new(tw, 20)
            btn.BG.Position = Vector2.new(tx + (i - 1) * (tw + sp), ty)
            btn.Text.Position = btn.BG.Position + btn.BG.Size / 2
            btn.BG.Visible = true; btn.Text.Visible = true
        end
    end
    if self.ATab then
        local yOff = ty + 25
        for _, e in ipairs(self.ATab.els) do
            e:U(self.Pos.X + 10, yOff)
            yOff = yOff + e.sz.Y + 3
        end
    end
end

function n:Destroy()
    for _, d in ipairs(self.WDraws) do d:Remove() end
    for _, tab in ipairs(self.Tabs) do
        if tab.tbBtn then tab.tbBtn.BG:Remove(); tab.tbBtn.Text:Remove() end
        for _, e in ipairs(tab.els) do e:R() end
    end
    for i, w in ipairs(self.Lib.Windows) do
        if w == self then table.remove(self.Lib.Windows, i); break end
    end
end

-- Library (p)
local p = {}
p.Windows = {}
p.__index = p

function p:W(title, pos, size)
    return n.new(self, title, pos, size)
end

-- Input handling
local dw, ds = nil, nil

b.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local m = Vector2.new(d.X, d.Y)
        local ws = p.Windows
        for i = #ws, 1, -1 do
            local w = ws[i]
            if not w.Vis then goto continue end
            if m.X >= w.CloseBtn.Position.X - 5 and m.X <= w.CloseBtn.Position.X + 15 and m.Y >= w.CloseBtn.Position.Y - 5 and m.Y <= w.CloseBtn.Position.Y + 15 then
                w:Destroy(); return
            end
            if m.X >= w.Pos.X and m.X <= w.Pos.X + w.Size.X and m.Y >= w.Pos.Y and m.Y <= w.Pos.Y + 25 then
                dw = w; w.DragOff = w.Pos - m; return
            end
            for _, tab in ipairs(w.Tabs) do
                local btn = tab.tbBtn
                if btn and btn.BG.Visible then
                    local bp = btn.BG.Position; local bs = btn.BG.Size
                    if m.X >= bp.X and m.X <= bp.X + bs.X and m.Y >= bp.Y and m.Y <= bp.Y + bs.Y then
                        w:SAT(tab); return
                    end
                end
            end
            if w.ATab then
                for _, e in ipairs(w.ATab.els) do
                    if e:H(m) then
                        if e:IS(m) then
                            ds = e; e:UM(m.X); return
                        elseif e:IS(i) or e:IS(j) then
                            e:O(); return
                        end
                    end
                end
            end
            ::continue::
        end
    end
end)

b.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dw, ds = nil, nil
    end
end)

c.RenderStepped:Connect(function()
    local m = Vector2.new(d.X, d.Y)
    if dw then
        dw.Pos = m + dw.DragOff
        dw:RFL()
    end
    if ds then
        ds:UM(m.X)
        ds.t.W:RFL()
    end
end)

return p
