--[[
    Halcyon  -  Roblox UI library  -  v1.1.0

    Load:   local Halcyon = loadstring(readfile("Halcyon.lua"))()
            -- or loadstring(game:HttpGet("<your raw url>"))()

    Docs:   HALCYON_DOCS.md

    Design notes
      * Icon rail on the left that expands over the content on hover (or pinned with the menu button)
      * Minimize collapses the window into a draggable orb
      * Animated gradient border, live theme switching, per-tab element search
      * Inline-expanding dropdowns and color pickers (no popups, no z-index fights)
      * Flags + JSON configs, notifications, dialogs, resizable window
]]

local env = (getgenv and getgenv()) or _G
if env.__Halcyon and type(env.__Halcyon.Destroy) == "function" then
    pcall(function() env.__Halcyon:Destroy() end)
end

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")

local Halcyon = {
    Version = "1.1.0",
    Flags   = {},
    Windows = {},
    Themes  = {},
    _binds  = {},
    _hooks  = {},
}

local Window    = {}; Window.__index = Window
local Container = {}; Container.__index = Container
local Tab       = setmetatable({}, { __index = Container }); Tab.__index = Tab
local Section   = setmetatable({}, { __index = Container }); Section.__index = Section
local Element   = {}; Element.__index = Element

local FONT_B, FONT_M, FONT_R = Enum.Font.GothamBold, Enum.Font.GothamMedium, Enum.Font.Gotham
local LEFT, RIGHT, CENTER = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center
local AUTO_X, AUTO_Y = Enum.AutomaticSize.X, Enum.AutomaticSize.Y
local TRUNCATE = Enum.TextTruncate.AtEnd

local TOP, RAIL_W, RAIL_OPEN = 46, 54, 184

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
local function C(r, g, b) return Color3.fromRGB(r, g, b) end

Halcyon.Themes = {
    Midnight = {
        Background = C(13, 14, 19),  Surface = C(18, 19, 26),  Element = C(24, 26, 35),
        ElementHover = C(31, 33, 45), Stroke = C(40, 43, 58),  Text = C(232, 234, 243),
        SubText = C(130, 135, 158),  Accent = C(124, 131, 255), Track = C(44, 47, 64),
    },
    Ember = {
        Background = C(18, 14, 13),  Surface = C(24, 19, 18),  Element = C(32, 26, 24),
        ElementHover = C(41, 33, 30), Stroke = C(58, 47, 43),  Text = C(245, 236, 230),
        SubText = C(160, 140, 130),  Accent = C(255, 128, 84),  Track = C(58, 48, 44),
    },
    Moss = {
        Background = C(12, 17, 15),  Surface = C(17, 23, 20),  Element = C(23, 31, 27),
        ElementHover = C(30, 41, 36), Stroke = C(38, 54, 46),  Text = C(230, 242, 236),
        SubText = C(125, 152, 138),  Accent = C(98, 214, 150),  Track = C(40, 56, 48),
    },
    Paper = {
        Background = C(243, 243, 246), Surface = C(250, 250, 252), Element = C(255, 255, 255),
        ElementHover = C(236, 237, 243), Stroke = C(216, 218, 228), Text = C(28, 30, 40),
        SubText = C(110, 114, 134),    Accent = C(88, 96, 240),    Track = C(205, 208, 222),
    },
}

local function derive(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    out.AccentDim = out.Accent:Lerp(out.Element, 0.82)
    local lum = 0.299 * out.Accent.R + 0.587 * out.Accent.G + 0.114 * out.Accent.B
    out.AccentText = lum > 0.62 and C(18, 18, 24) or C(255, 255, 255)
    out.Danger = C(240, 98, 98)
    return out
end

local function fillTheme(t)
    local out = {}
    for k, v in pairs(Halcyon.Themes.Midnight) do out[k] = v end
    for k, v in pairs(t) do out[k] = v end
    return out
end

Halcyon._base = Halcyon.Themes.Midnight
Halcyon.Theme = derive(Halcyon._base)

function Halcyon:_bind(inst, map)
    for prop, key in pairs(map) do
        inst[prop] = self.Theme[key]
        table.insert(self._binds, { inst = inst, prop = prop, key = key })
    end
    return inst
end

function Halcyon:_hook(owner, fn)
    table.insert(self._hooks, { owner = owner, fn = fn })
    fn(self.Theme, false)
end

function Halcyon:_refresh(animate)
    local th = self.Theme
    for i = #self._binds, 1, -1 do
        local b = self._binds[i]
        if not b.inst.Parent then
            table.remove(self._binds, i)
        else
            if animate then
                TweenService:Create(b.inst, TweenInfo.new(0.25), { [b.prop] = th[b.key] }):Play()
            else
                b.inst[b.prop] = th[b.key]
            end
        end
    end
    for i = #self._hooks, 1, -1 do
        local h = self._hooks[i]
        if not h.owner.Parent then
            table.remove(self._hooks, i)
        else
            pcall(h.fn, th, animate)
        end
    end
end

function Halcyon:_rebuild(animate)
    local base = {}
    for k, v in pairs(self._base) do base[k] = v end
    if self._accent then base.Accent = self._accent end
    self.Theme = derive(base)
    self:_refresh(animate)
end

function Halcyon:SetTheme(t)
    if type(t) == "string" then
        if not self.Themes[t] then
            warn("[Halcyon] unknown theme: " .. t)
            return
        end
        self._base = self.Themes[t]
        self._themeName = t
    elseif type(t) == "table" then
        self._base = fillTheme(t)
    else
        return
    end
    self._accent = nil
    self:_rebuild(self._gui ~= nil)
end

function Halcyon:SetAccent(color)
    self._accent = color
    self:_rebuild(self._gui ~= nil)
end

function Halcyon:AddTheme(name, tbl)
    self.Themes[name] = fillTheme(tbl)
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function B(inst, map) return Halcyon:_bind(inst, map) end

local function New(class, props)
    local inst = Instance.new(class)
    local isText = false
    if inst:IsA("GuiObject") then
        inst.BorderSizePixel = 0
        if inst:IsA("GuiButton") then inst.AutoButtonColor = false end
        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            isText = true
            inst.Text = ""
            inst.BackgroundTransparency = 1
            inst.Font = FONT_M
            inst.TextSize = 13
        end
    end
    local parent
    local map = {}
    local explicitColor = false
    for k, v in pairs(props or {}) do
        if k == "Parent" then
            parent = v
        elseif k == "Bind" then
            for pk, pv in pairs(v) do map[pk] = pv end
        else
            if k == "TextColor3" then explicitColor = true end
            inst[k] = v
        end
    end
    if isText and not map.TextColor3 and not explicitColor then map.TextColor3 = "Text" end
    if next(map) then Halcyon:_bind(inst, map) end
    if parent then inst.Parent = parent end
    return inst
end

local function Corner(parent, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

local function Pad(parent, l, t, r, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b), Parent = parent,
    })
end

local function List(parent, pad, dir, ha, va)
    return New("UIListLayout", {
        Padding = UDim.new(0, pad or 0),
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
        VerticalAlignment = va or Enum.VerticalAlignment.Top,
        Parent = parent,
    })
end

local function Stroke(parent, key, thickness)
    return New("UIStroke", {
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Bind = { Color = key or "Stroke" },
        Parent = parent,
    })
end

local function Tween(inst, time, props, style, dir)
    local tw = TweenService:Create(inst,
        TweenInfo.new(time, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Halcyon] callback error: " .. tostring(err)) end
end

-- Pointer in the ScreenGui's (IgnoreGuiInset = true) coordinate space.
local function Pointer(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        local inset = GuiService:GetGuiInset()
        return Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
    end
    return UserInputService:GetMouseLocation()
end

local function viewport()
    local gui = Halcyon._gui
    local s = gui and gui.AbsoluteSize or Vector2.new(0, 0)
    if s.X < 100 or s.Y < 100 then
        local cam = workspace.CurrentCamera
        s = cam and cam.ViewportSize or Vector2.new(1280, 720)
    end
    return s
end

local function hexOf(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function parseHex(s)
    local r, g, b = tostring(s):match("#?(%x%x)(%x%x)(%x%x)")
    if not r then return nil end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function BindDrag(win, hit, onStart, onMove, onEnd)
    local active = false
    win:_connect(hit.InputBegan, function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            active = true
            local p = Pointer(input)
            if onStart then onStart(p) end
            if onMove then onMove(p) end
        end
    end)
    win:_connect(UserInputService.InputChanged, function(input)
        if not active then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch then
            if onMove then onMove(Pointer(input)) end
        end
    end)
    win:_connect(UserInputService.InputEnded, function(input)
        local t = input.UserInputType
        if active and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
            active = false
            if onEnd then onEnd() end
        end
    end)
end

local function Hit(parent, z)
    return New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = z or 2, Parent = parent })
end

local function HoverCard(card, hit)
    hit.MouseEnter:Connect(function()
        Tween(card, 0.12, { BackgroundColor3 = Halcyon.Theme.ElementHover })
    end)
    hit.MouseLeave:Connect(function()
        Tween(card, 0.12, { BackgroundColor3 = Halcyon.Theme.Element })
    end)
end

local function HoverBtn(btn, key)
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Halcyon.Theme[key or "ElementHover"]
        Tween(btn, 0.12, { BackgroundTransparency = 0 })
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.12, { BackgroundTransparency = 1 })
    end)
end

local function Ripple(card, p)
    local r = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(p.X - card.AbsolutePosition.X, p.Y - card.AbsolutePosition.Y),
        Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.8, ZIndex = 0,
        Bind = { BackgroundColor3 = "Accent" }, Parent = card,
    })
    Corner(r, 999)
    local d = math.max(card.AbsoluteSize.X, card.AbsoluteSize.Y) * 2.2
    Tween(r, 0.5, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 })
    task.delay(0.55, function() r:Destroy() end)
end

local function baseHeight(opts)
    return (opts.Desc and opts.Desc ~= "") and 54 or 40
end

local function nameOf(opts)
    return (opts.Title or "") .. " " .. (opts.Desc or "")
end

local function Header(card, opts, rightPad)
    local hasDesc = opts.Desc and opts.Desc ~= ""
    rightPad = rightPad or 0
    local title = New("TextLabel", {
        Position = UDim2.fromOffset(14, hasDesc and 9 or 0),
        Size = UDim2.new(1, -(28 + rightPad), 0, hasDesc and 18 or 40),
        Text = opts.Title or "", TextXAlignment = LEFT, TextTruncate = TRUNCATE, Parent = card,
    })
    local desc
    if hasDesc then
        desc = New("TextLabel", {
            Position = UDim2.fromOffset(14, 28),
            Size = UDim2.new(1, -(28 + rightPad), 0, 16),
            Text = opts.Desc, TextSize = 11, Font = FONT_R, TextXAlignment = LEFT, TextTruncate = TRUNCATE,
            Bind = { TextColor3 = "SubText" }, Parent = card,
        })
    end
    return title, desc
end

----------------------------------------------------------------------
-- Library level: gui, notifications, configs
----------------------------------------------------------------------
local function resolveParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok = pcall(function() return CoreGui.Name end)
    if ok then return CoreGui end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

function Halcyon:_ensureGui()
    if self._gui and self._gui.Parent then return self._gui end
    local gui = Instance.new("ScreenGui")
    gui.Name = HttpService:GenerateGUID(false)
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if type(syn) == "table" and syn.protect_gui then pcall(syn.protect_gui, gui) end
    gui.Parent = resolveParent()
    self._gui = gui

    self._toastHolder = New("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.new(0, 300, 1, -32), BackgroundTransparency = 1, Parent = gui,
    })
    List(self._toastHolder, 8, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
    return gui
end

local TYPE_COLORS = {
    Success = C(74, 222, 128),
    Warning = C(251, 191, 36),
    Error   = C(248, 113, 113),
}

function Halcyon:Notify(opts)
    if type(opts) == "string" then opts = { Content = opts } end
    opts = opts or {}
    self:_ensureGui()
    self._toastN = (self._toastN or 0) + 1
    local dur = opts.Duration or 4
    local kind = opts.Type or "Info"
    local color = TYPE_COLORS[kind]

    local outer = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, BackgroundTransparency = 1,
        LayoutOrder = -self._toastN, Parent = self._toastHolder,
    })
    local card = New("Frame", {
        Position = UDim2.new(1, 60, 0, 0), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y,
        Bind = { BackgroundColor3 = "Element" }, Parent = outer,
    })
    Corner(card, 10)
    Stroke(card)

    local inner = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, BackgroundTransparency = 1, Parent = card,
    })
    List(inner, 0)

    local body = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, BackgroundTransparency = 1,
        LayoutOrder = 1, Parent = inner,
    })
    Pad(body, 18, 11, 12, 10)
    List(body, 2)

    local tprops = { Size = UDim2.new(1, 0, 0, 18), Text = opts.Title or kind, Font = FONT_B,
        TextXAlignment = LEFT, LayoutOrder = 1, Parent = body }
    if color then tprops.TextColor3 = color else tprops.Bind = { TextColor3 = "Accent" } end
    New("TextLabel", tprops)

    if opts.Content and opts.Content ~= "" then
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, Text = opts.Content, TextSize = 12,
            Font = FONT_R, TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = 2,
            Bind = { TextColor3 = "SubText" }, Parent = body,
        })
    end

    local bar = New("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 1, LayoutOrder = 2, Parent = inner })
    local fillProps = { Size = UDim2.fromScale(1, 1), Parent = bar }
    if color then fillProps.BackgroundColor3 = color else fillProps.Bind = { BackgroundColor3 = "Accent" } end
    local fill = New("Frame", fillProps)

    local sideProps = { Size = UDim2.new(0, 3, 1, 0), Parent = card }
    if color then sideProps.BackgroundColor3 = color else sideProps.Bind = { BackgroundColor3 = "Accent" } end
    New("Frame", sideProps)

    local closed = false
    local function close()
        if closed then return end
        closed = true
        Tween(card, 0.3, { Position = UDim2.new(1, 60, 0, 0) })
        task.delay(0.35, function() outer:Destroy() end)
    end
    local click = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
    click.MouseButton1Click:Connect(close)

    Tween(card, 0.4, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
    if dur > 0 then
        Tween(fill, dur, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear)
        task.delay(dur, close)
    else
        bar.Visible = false
    end
    return { Close = close }
end

function Halcyon:ExportConfig()
    local out = {}
    for flag, el in pairs(self.Flags) do
        local v = el.Value
        if el.Type == "ColorPicker" then
            v = { __color = hexOf(v) }
        elseif el.Type == "Keybind" then
            v = { __key = v.Name }
        end
        out[flag] = v
    end
    return HttpService:JSONEncode(out)
end

function Halcyon:ImportConfig(json)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" then return false, "invalid json" end
    for flag, v in pairs(data) do
        local el = self.Flags[flag]
        if el then
            if type(v) == "table" and v.__color then
                local c = parseHex(v.__color)
                if c then el:Set(c) end
            elseif type(v) == "table" and v.__key then
                el:Set(v.__key)
            else
                el:Set(v)
            end
        end
    end
    return true
end

function Halcyon:GetFlag(name)
    local el = self.Flags[name]
    if el then return el.Value end
    return nil
end

function Halcyon:Destroy()
    for i = #self.Windows, 1, -1 do
        local w = self.Windows[i]
        if w then w:Destroy() end
    end
    if self._gui then self._gui:Destroy() end
    self._gui = nil
    self._binds, self._hooks, self.Flags = {}, {}, {}
    if env.__Halcyon == self then env.__Halcyon = nil end
end

----------------------------------------------------------------------
-- Element base
----------------------------------------------------------------------
function Element:Get() return self.Value end

function Element:OnChanged(fn)
    table.insert(self._listeners, fn)
    return self
end

function Element:_emit(...)
    if self.Callback then task.spawn(safe, self.Callback, ...) end
    for _, l in ipairs(self._listeners) do task.spawn(safe, l, ...) end
end

function Element:SetVisible(v)
    self._hidden = not v
    self.Frame.Visible = v
end

function Element:SetTitle(t)
    if self._title then self._title.Text = t end
    self._entry.Name = t
end

function Element:SetDesc(t)
    if self._desc then self._desc.Text = t end
end

function Element:Destroy()
    if self.Flag and Halcyon.Flags[self.Flag] == self then Halcyon.Flags[self.Flag] = nil end
    local list = self._container._entries
    for i, e in ipairs(list) do
        if e == self._entry then
            table.remove(list, i)
            break
        end
    end
    self.Frame:Destroy()
end

----------------------------------------------------------------------
-- Container (shared by Tab and Section)
----------------------------------------------------------------------
function Container:_next()
    self._order = self._order + 1
    return self._order
end

function Container:_card(height)
    local f = New("Frame", {
        Size = UDim2.new(1, 0, 0, height), LayoutOrder = self:_next(), ClipsDescendants = true,
        Bind = { BackgroundColor3 = "Element" }, Parent = self._parent,
    })
    Corner(f, 8)
    Stroke(f)
    return f
end

function Container:_element(kind, opts, frame, name, title, desc)
    local el = setmetatable({
        Type = kind, Frame = frame, Flag = opts.Flag, Callback = opts.Callback,
        _listeners = {}, _hidden = false, _title = title, _desc = desc, _container = self,
    }, Element)
    local entry = { Name = name or "", Frame = frame, Element = el }
    table.insert(self._entries, entry)
    el._entry = entry
    if opts.Flag then
        Halcyon.Flags[opts.Flag] = el
        self.Window._flags[opts.Flag] = el
    end
    return el
end

function Container:_filter(term)
    local count = 0
    for _, e in ipairs(self._entries) do
        if e.Section then
            local n = e.Section:_filter(term)
            if term == "" or n > 0 then count = count + 1 end
        else
            local hidden = e.Element and e.Element._hidden
            local match = term == "" or (e.Name ~= "" and e.Name:lower():find(term, 1, true) ~= nil)
            local show = match and not hidden
            e.Frame.Visible = show
            if show then count = count + 1 end
        end
    end
    return count
end

-- Label ---------------------------------------------------------------
function Container:AddLabel(opts)
    if type(opts) == "string" then opts = { Text = opts } end
    opts = opts or {}
    local lbl = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, Text = opts.Text or "", Font = FONT_R,
        TextSize = 12, TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = self:_next(),
        Bind = { TextColor3 = "SubText" }, Parent = self._parent,
    })
    Pad(lbl, 4, 2, 4, 2)
    local el = self:_element("Label", opts, lbl, opts.Text or "", lbl)
    function el:SetText(t)
        lbl.Text = t
        self._entry.Name = t
    end
    return el
end

-- Paragraph -----------------------------------------------------------
function Container:AddParagraph(opts)
    opts = opts or {}
    local card = self:_card(0)
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = AUTO_Y
    Pad(card, 14, 12, 14, 12)
    List(card, 4)
    local t = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, Text = opts.Title or "", Font = FONT_B,
        TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = 1, Parent = card,
    })
    t.Visible = (opts.Title or "") ~= ""
    local c = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, Text = opts.Content or "", Font = FONT_R,
        TextSize = 12, TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = 2,
        Bind = { TextColor3 = "SubText" }, Parent = card,
    })
    local el = self:_element("Paragraph", opts, card, (opts.Title or "") .. " " .. (opts.Content or ""), t)
    function el:SetContent(s) c.Text = s end
    return el
end

-- Divider -------------------------------------------------------------
function Container:AddDivider()
    local d = New("Frame", {
        Size = UDim2.new(1, 0, 0, 1), LayoutOrder = self:_next(),
        Bind = { BackgroundColor3 = "Stroke" }, Parent = self._parent,
    })
    return self:_element("Divider", {}, d, "")
end

-- Button --------------------------------------------------------------
function Container:AddButton(opts)
    if type(opts) == "string" then opts = { Title = opts } end
    opts = opts or {}
    local hh = baseHeight(opts)
    local card = self:_card(hh)
    local title, desc = Header(card, opts, 30)
    New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.fromOffset(14, hh),
        Text = ">", TextSize = 16, Font = FONT_B, Bind = { TextColor3 = "SubText" }, Parent = card,
    })
    local hit = Hit(card)
    HoverCard(card, hit)
    local el = self:_element("Button", opts, card, nameOf(opts), title, desc)
    hit.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            Ripple(card, Pointer(input))
        end
    end)
    hit.MouseButton1Click:Connect(function() el:_emit() end)
    function el:Fire() self:_emit() end
    return el
end

-- Toggle --------------------------------------------------------------
function Container:AddToggle(opts)
    opts = opts or {}
    local hh = baseHeight(opts)
    local card = self:_card(hh)
    local title, desc = Header(card, opts, 56)
    local track = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, hh / 2),
        Size = UDim2.fromOffset(40, 22), Parent = card,
    })
    Corner(track, 11)
    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
    })
    Corner(knob, 8)
    local hit = Hit(card)
    HoverCard(card, hit)
    local el = self:_element("Toggle", opts, card, nameOf(opts), title, desc)
    el.Value = opts.Default == true

    local function render(animate)
        local th = Halcyon.Theme
        local t = animate and 0.18 or 0
        Tween(track, t, { BackgroundColor3 = el.Value and th.Accent or th.Track })
        Tween(knob, t, { Position = el.Value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
    end
    Halcyon:_hook(card, function() render(false) end)

    function el:Set(v, silent)
        v = v and true or false
        if v == self.Value then return end
        self.Value = v
        render(true)
        if not silent then self:_emit(v) end
    end
    function el:Toggle() self:Set(not self.Value) end

    hit.MouseButton1Click:Connect(function() el:Toggle() end)
    if opts.FireOnCreate then el:_emit(el.Value) end
    return el
end

-- Slider --------------------------------------------------------------
function Container:AddSlider(opts)
    opts = opts or {}
    local min, max = opts.Min or 0, opts.Max or 100
    local inc = opts.Increment or 1
    local suffix = opts.Suffix or ""
    local dec = 0
    local frac = tostring(inc):match("%.(%d+)")
    if frac then dec = #frac end

    local hh = baseHeight(opts)
    local card = self:_card(hh + 16)
    local title, desc = Header(card, opts, 80)

    local boxWrap = New("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 9), Size = UDim2.fromOffset(64, 22),
        Bind = { BackgroundColor3 = "Surface" }, Parent = card,
    })
    Corner(boxWrap, 6)
    Stroke(boxWrap)
    local box = New("TextBox", {
        Size = UDim2.fromScale(1, 1), TextSize = 12, ClearTextOnFocus = false, Parent = boxWrap,
    })

    local track = New("Frame", {
        Position = UDim2.new(0, 14, 0, hh - 2), Size = UDim2.new(1, -28, 0, 6),
        Bind = { BackgroundColor3 = "Track" }, Parent = card,
    })
    Corner(track, 3)
    local fill = New("Frame", { Size = UDim2.fromScale(0, 1), Bind = { BackgroundColor3 = "Accent" }, Parent = track })
    Corner(fill, 3)
    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = track,
    })
    Corner(knob, 9)
    Stroke(knob, "Accent", 2)
    local hit = New("TextButton", {
        Position = UDim2.new(0, 14, 0, hh - 9), Size = UDim2.new(1, -28, 0, 20), ZIndex = 4, Parent = card,
    })

    local el = self:_element("Slider", opts, card, nameOf(opts), title, desc)

    local function snap(v)
        v = math.clamp(v, min, max)
        v = min + math.floor((v - min) / inc + 0.5) * inc
        v = math.clamp(v, min, max)
        return tonumber(string.format("%." .. dec .. "f", v))
    end
    local function fmt(v) return string.format("%." .. dec .. "f", v) .. suffix end

    el.Value = snap(opts.Default or min)

    local function render(animate)
        local a = (max == min) and 0 or (el.Value - min) / (max - min)
        local t = animate and 0.08 or 0
        Tween(fill, t, { Size = UDim2.fromScale(a, 1) })
        Tween(knob, t, { Position = UDim2.new(a, 0, 0.5, 0) })
        box.Text = fmt(el.Value)
    end
    render(false)

    function el:Set(v, silent)
        v = snap(tonumber(v) or self.Value)
        if v == self.Value then
            render(false)
            return
        end
        self.Value = v
        render(true)
        if not silent then self:_emit(v) end
    end

    BindDrag(self.Window, hit,
        function() Tween(knob, 0.1, { Size = UDim2.fromOffset(18, 18) }) end,
        function(p)
            local a = math.clamp((p.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            el:Set(min + (max - min) * a)
        end,
        function() Tween(knob, 0.1, { Size = UDim2.fromOffset(14, 14) }) end)

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text:match("-?%d+%.?%d*"))
        if n then el:Set(n) else render(false) end
    end)

    if opts.FireOnCreate then el:_emit(el.Value) end
    return el
end

-- Input ---------------------------------------------------------------
function Container:AddInput(opts)
    opts = opts or {}
    local hh = baseHeight(opts)
    local width = opts.Width or 150
    local card = self:_card(hh)
    local title, desc = Header(card, opts, width + 10)
    local wrap = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, hh / 2), Size = UDim2.fromOffset(width, 28),
        Bind = { BackgroundColor3 = "Surface" }, Parent = card,
    })
    Corner(wrap, 6)
    local st = Stroke(wrap)
    local box = New("TextBox", {
        Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -16, 1, 0), Text = tostring(opts.Default or ""),
        PlaceholderText = opts.Placeholder or "", ClearTextOnFocus = false, TextSize = 12, TextXAlignment = LEFT,
        Bind = { PlaceholderColor3 = "SubText" }, Parent = wrap,
    })
    local el = self:_element("Input", opts, card, nameOf(opts), title, desc)
    el.Value = box.Text
    local setting = false

    box:GetPropertyChangedSignal("Text"):Connect(function()
        if setting then return end
        if opts.Numeric then
            local cleaned = box.Text:gsub("[^%d%.%-]", "")
            if cleaned ~= box.Text then
                box.Text = cleaned
                return
            end
        end
        if opts.Live then
            el.Value = box.Text
            el:_emit(el.Value)
        end
    end)
    box.Focused:Connect(function() Tween(st, 0.15, { Color = Halcyon.Theme.Accent }) end)
    box.FocusLost:Connect(function()
        Tween(st, 0.15, { Color = Halcyon.Theme.Stroke })
        local changed = el.Value ~= box.Text
        el.Value = box.Text
        if changed then el:_emit(el.Value) end
    end)

    function el:Set(v, silent)
        setting = true
        box.Text = tostring(v)
        setting = false
        self.Value = box.Text
        if not silent then self:_emit(self.Value) end
    end

    if opts.FireOnCreate then el:_emit(el.Value) end
    return el
end

-- Dropdown ------------------------------------------------------------
function Container:AddDropdown(opts)
    opts = opts or {}
    local multi = opts.Multi == true
    local hh = baseHeight(opts)
    local rowH, gap = 28, 2
    local maxRows = opts.MaxRows or 6
    local card = self:_card(hh)
    local title, desc = Header(card, opts, 170)

    local valueLbl = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 0), Size = UDim2.fromOffset(150, hh),
        TextXAlignment = RIGHT, TextTruncate = TRUNCATE, TextSize = 12, Font = FONT_R,
        Bind = { TextColor3 = "SubText" }, Parent = card,
    })
    local chevron = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -21, 0, hh / 2), Size = UDim2.fromOffset(14, 14),
        Text = ">", Rotation = 90, TextSize = 14, Font = FONT_B, Bind = { TextColor3 = "SubText" }, Parent = card,
    })
    local head = Hit(card)
    head.Size = UDim2.new(1, 0, 0, hh)
    HoverCard(card, head)

    local list = New("ScrollingFrame", {
        Position = UDim2.fromOffset(8, hh), Size = UDim2.new(1, -16, 0, 0), BackgroundTransparency = 1,
        ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = AUTO_Y, Visible = false,
        Bind = { ScrollBarImageColor3 = "Accent" }, Parent = card,
    })
    List(list, gap)

    local el = self:_element("Dropdown", opts, card, nameOf(opts), title, desc)
    local options, buttons = {}, {}
    local selected, single = {}, nil
    local open = false

    local function listHeight()
        local n = math.min(#options, maxRows)
        if n == 0 then return 0 end
        return n * rowH + (n - 1) * gap
    end
    local function openHeight() return hh + listHeight() + 8 end

    local function isSel(name)
        if multi then return selected[name] == true end
        return single == name
    end

    local function currentValue()
        if multi then
            local out = {}
            for _, o in ipairs(options) do
                if selected[o] then table.insert(out, o) end
            end
            return out
        end
        return single
    end

    local function paint()
        local th = Halcyon.Theme
        for name, b in pairs(buttons) do
            local sel = isSel(name)
            b.btn.BackgroundColor3 = th.AccentDim
            b.btn.BackgroundTransparency = sel and 0 or 1
            b.lbl.TextColor3 = sel and th.Accent or th.Text
            b.dot.Visible = sel
            b.dot.BackgroundColor3 = th.Accent
        end
        if multi then
            local v = el.Value or {}
            valueLbl.Text = #v == 0 and (opts.Placeholder or "None") or table.concat(v, ", ")
        else
            valueLbl.Text = el.Value or (opts.Placeholder or "Select")
        end
    end

    local function commit(silent)
        el.Value = currentValue()
        paint()
        if not silent then el:_emit(el.Value) end
    end

    local function setOpen(v)
        open = v
        if v then
            list.Visible = true
            list.Size = UDim2.new(1, -16, 0, listHeight())
            Tween(card, 0.22, { Size = UDim2.new(1, 0, 0, openHeight()) })
            Tween(chevron, 0.22, { Rotation = 270 })
        else
            Tween(card, 0.22, { Size = UDim2.new(1, 0, 0, hh) })
            Tween(chevron, 0.22, { Rotation = 90 })
            task.delay(0.24, function()
                if not open and list.Parent then list.Visible = false end
            end)
        end
    end

    local function build()
        for _, b in pairs(buttons) do b.btn:Destroy() end
        buttons = {}
        for i, name in ipairs(options) do
            local btn = New("TextButton", { Size = UDim2.new(1, -4, 0, rowH), LayoutOrder = i, Parent = list })
            Corner(btn, 6)
            local lbl = New("TextLabel", {
                Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0), Text = name, TextSize = 12,
                TextXAlignment = LEFT, TextTruncate = TRUNCATE, Parent = btn,
            })
            local dot = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(6, 6),
                Visible = false, Parent = btn,
            })
            Corner(dot, 3)
            buttons[name] = { btn = btn, lbl = lbl, dot = dot }
            btn.MouseEnter:Connect(function()
                if not isSel(name) then
                    btn.BackgroundColor3 = Halcyon.Theme.ElementHover
                    Tween(btn, 0.1, { BackgroundTransparency = 0 })
                end
            end)
            btn.MouseLeave:Connect(function()
                if not isSel(name) then Tween(btn, 0.1, { BackgroundTransparency = 1 }) end
            end)
            btn.MouseButton1Click:Connect(function()
                if multi then
                    selected[name] = (not selected[name]) or nil
                    commit()
                else
                    single = name
                    commit()
                    setOpen(false)
                end
            end)
        end
        if open then
            list.Size = UDim2.new(1, -16, 0, listHeight())
            Tween(card, 0.22, { Size = UDim2.new(1, 0, 0, openHeight()) })
        end
    end

    for _, o in ipairs(opts.Options or {}) do table.insert(options, tostring(o)) end
    build()
    if multi then
        if type(opts.Default) == "table" then
            for _, d in ipairs(opts.Default) do
                if buttons[tostring(d)] then selected[tostring(d)] = true end
            end
        end
    elseif opts.Default ~= nil and buttons[tostring(opts.Default)] then
        single = tostring(opts.Default)
    end
    commit(true)
    Halcyon:_hook(card, function() paint() end)

    function el:Set(v, silent)
        if multi then
            selected = {}
            if type(v) == "table" then
                for _, x in ipairs(v) do
                    if buttons[tostring(x)] then selected[tostring(x)] = true end
                end
            end
        else
            single = (v ~= nil and buttons[tostring(v)]) and tostring(v) or nil
        end
        commit(silent)
    end
    function el:Get()
        if multi then
            local out = {}
            for i, v in ipairs(self.Value) do out[i] = v end
            return out
        end
        return self.Value
    end
    function el:Refresh(newOptions, keep)
        local prevSingle, prevSel = single, selected
        options = {}
        for _, o in ipairs(newOptions or {}) do table.insert(options, tostring(o)) end
        build()
        single, selected = nil, {}
        if keep then
            if multi then
                for k in pairs(prevSel) do
                    if buttons[k] then selected[k] = true end
                end
            elseif prevSingle and buttons[prevSingle] then
                single = prevSingle
            end
        end
        commit(true)
    end
    function el:Open() setOpen(true) end
    function el:Close() setOpen(false) end

    head.MouseButton1Click:Connect(function() setOpen(not open) end)
    if opts.FireOnCreate then el:_emit(el.Value) end
    return el
end

-- Keybind -------------------------------------------------------------
function Container:AddKeybind(opts)
    opts = opts or {}
    local hh = baseHeight(opts)
    local card = self:_card(hh)
    local title, desc = Header(card, opts, 110)
    local btn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, hh / 2), Size = UDim2.fromOffset(96, 26),
        TextSize = 12, BackgroundTransparency = 0, Bind = { BackgroundColor3 = "Surface", TextColor3 = "SubText" },
        Parent = card,
    })
    Corner(btn, 6)
    local st = Stroke(btn)
    local hit = Hit(card, 1)
    HoverCard(card, hit)
    btn.ZIndex = 3

    local function toKey(k)
        if typeof(k) == "EnumItem" then return k end
        if type(k) == "string" then
            local ok, v = pcall(function() return Enum.KeyCode[k] end)
            if ok then return v end
        end
        return nil
    end

    local el = self:_element("Keybind", opts, card, nameOf(opts), title, desc)
    el.Value = toKey(opts.Default) or Enum.KeyCode.Unknown
    local mode = opts.Mode or "Press"
    local listening, held = false, false

    local function label()
        btn.Text = (el.Value == Enum.KeyCode.Unknown) and "None" or el.Value.Name
    end
    label()

    function el:Set(k, silent)
        k = toKey(k)
        if not k then return end
        self.Value = k
        label()
        if not silent then
            for _, l in ipairs(self._listeners) do task.spawn(safe, l, k) end
        end
    end
    function el:IsDown() return held end

    btn.MouseButton1Click:Connect(function()
        listening = true
        Halcyon._listening = true
        btn.Text = "..."
        Tween(st, 0.15, { Color = Halcyon.Theme.Accent })
    end)

    self.Window:_connect(UserInputService.InputBegan, function(input, gpe)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                Halcyon._listening = false
                Tween(st, 0.15, { Color = Halcyon.Theme.Stroke })
                if input.KeyCode == Enum.KeyCode.Escape then
                    el:Set(Enum.KeyCode.Unknown)
                else
                    el:Set(input.KeyCode)
                end
            end
            return
        end
        if gpe or el.Value == Enum.KeyCode.Unknown then return end
        if input.KeyCode == el.Value then
            if mode == "Hold" then
                held = true
                task.spawn(safe, el.Callback, true)
            else
                task.spawn(safe, el.Callback, el.Value)
            end
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(input)
        if mode == "Hold" and held and input.KeyCode == el.Value then
            held = false
            task.spawn(safe, el.Callback, false)
        end
    end)
    return el
end

-- ColorPicker ---------------------------------------------------------
function Container:AddColorPicker(opts)
    opts = opts or {}
    local hh = baseHeight(opts)
    local PANEL_H = 170
    local card = self:_card(hh)
    local title, desc = Header(card, opts, 60)

    local swatch = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, hh / 2), Size = UDim2.fromOffset(40, 20),
        Parent = card,
    })
    Corner(swatch, 6)
    Stroke(swatch)
    local head = Hit(card)
    head.Size = UDim2.new(1, 0, 0, hh)
    HoverCard(card, head)

    local panel = New("Frame", {
        Position = UDim2.fromOffset(0, hh), Size = UDim2.new(1, 0, 0, PANEL_H), BackgroundTransparency = 1,
        Visible = false, Parent = card,
    })

    local sv = New("Frame", { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 100), Parent = panel })
    Corner(sv, 6)
    local white = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sv })
    Corner(white, 6)
    New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
    local black = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = sv })
    Corner(black, 6)
    New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
    local cursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
        ZIndex = 3, Parent = sv,
    })
    Corner(cursor, 6)
    New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = cursor })
    local svHit = New("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = sv })

    local hue = New("Frame", {
        Position = UDim2.fromOffset(14, 114), Size = UDim2.new(1, -28, 0, 12), BackgroundColor3 = Color3.new(1, 1, 1),
        Parent = panel,
    })
    Corner(hue, 6)
    local kps = {}
    for i = 0, 6 do
        table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.9999), 1, 1)))
    end
    New("UIGradient", { Color = ColorSequence.new(kps), Parent = hue })
    local hueCursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 18), BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 3, Parent = hue,
    })
    Corner(hueCursor, 3)
    New("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = hueCursor })
    local hueHit = New("TextButton", { Size = UDim2.new(1, 0, 1, 8), Position = UDim2.fromOffset(0, -4), ZIndex = 5, Parent = hue })

    local hexWrap = New("Frame", {
        Position = UDim2.fromOffset(14, 134), Size = UDim2.new(1, -28, 0, 26), Bind = { BackgroundColor3 = "Surface" },
        Parent = panel,
    })
    Corner(hexWrap, 6)
    Stroke(hexWrap)
    local hex = New("TextBox", {
        Size = UDim2.fromScale(1, 1), TextSize = 12, ClearTextOnFocus = false, Parent = hexWrap,
    })

    local el = self:_element("ColorPicker", opts, card, nameOf(opts), title, desc)
    local h, s, v = Color3.new(1, 0, 0):ToHSV()
    local def = opts.Default or Color3.fromRGB(255, 255, 255)
    h, s, v = def:ToHSV()
    el.Value = def

    local function apply(silent)
        local col = Color3.fromHSV(h, s, v)
        el.Value = col
        swatch.BackgroundColor3 = col
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        cursor.Position = UDim2.new(s, 0, 1 - v, 0)
        hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
        if not hex:IsFocused() then hex.Text = hexOf(col) end
        if not silent then el:_emit(col) end
    end
    apply(true)

    BindDrag(self.Window, svHit, nil, function(p)
        s = math.clamp((p.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
        apply()
    end)
    BindDrag(self.Window, hueHit, nil, function(p)
        h = math.clamp((p.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1)
        apply()
    end)
    hex.FocusLost:Connect(function()
        local c = parseHex(hex.Text)
        if c then
            h, s, v = c:ToHSV()
            apply()
        end
        hex.Text = hexOf(el.Value)
    end)

    function el:Set(c, silent)
        if typeof(c) ~= "Color3" then return end
        h, s, v = c:ToHSV()
        apply(silent)
    end
    function el:GetHex() return hexOf(self.Value) end

    local open = false
    head.MouseButton1Click:Connect(function()
        open = not open
        if open then
            panel.Visible = true
            Tween(card, 0.22, { Size = UDim2.new(1, 0, 0, hh + PANEL_H) })
        else
            Tween(card, 0.22, { Size = UDim2.new(1, 0, 0, hh) })
            task.delay(0.24, function()
                if not open and panel.Parent then panel.Visible = false end
            end)
        end
    end)

    if opts.FireOnCreate then el:_emit(el.Value) end
    return el
end

-- Section -------------------------------------------------------------
function Container:AddSection(opts)
    if type(opts) == "string" then opts = { Title = opts } end
    opts = opts or {}
    local frame = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, BackgroundTransparency = 1,
        LayoutOrder = self:_next(), Parent = self._parent,
    })
    List(frame, 8)
    local head = New("TextButton", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = frame })
    New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1),
        Bind = { BackgroundColor3 = "Stroke" }, Parent = head,
    })
    local title = New("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AUTO_X, Text = string.upper(opts.Title or "Section"),
        Font = FONT_B, TextSize = 11, BackgroundTransparency = 0,
        Bind = { TextColor3 = "Accent", BackgroundColor3 = "Background" }, Parent = head,
    })
    Pad(title, 0, 0, 8, 0)
    local chev = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = AUTO_X, Font = FONT_B, TextSize = 14, BackgroundTransparency = 0,
        Bind = { TextColor3 = "SubText", BackgroundColor3 = "Background" }, Parent = head,
    })
    Pad(chev, 8, 0, 0, 0)
    local body = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = frame,
    })
    List(body, 8)

    local sec = setmetatable({
        Window = self.Window, _parent = body, _entries = {}, _order = 0, Frame = frame, Body = body,
        _open = opts.Open ~= false, _title = title, _chev = chev, _container = self,
    }, Section)
    sec:_sync()
    head.MouseButton1Click:Connect(function() sec:Toggle() end)
    table.insert(self._entries, { Name = "", Frame = frame, Section = sec })
    return sec
end

function Section:_sync()
    self.Body.Visible = self._open or self._searching == true
    self._chev.Text = self._open and "-" or "+"
end
function Section:SetOpen(v)
    self._open = v and true or false
    self:_sync()
end
function Section:Toggle() self:SetOpen(not self._open) end
function Section:SetTitle(t) self._title.Text = string.upper(t) end
function Section:_filter(term)
    self._searching = term ~= ""
    local n = Container._filter(self, term)
    self.Frame.Visible = term == "" or n > 0
    self:_sync()
    return n
end
function Section:Destroy()
    local list = self._container._entries
    for i, e in ipairs(list) do
        if e.Section == self then
            table.remove(list, i)
            break
        end
    end
    self.Frame:Destroy()
end

----------------------------------------------------------------------
-- Tab
----------------------------------------------------------------------
function Tab:_paint(animate)
    local th = Halcyon.Theme
    local t = animate and 0.18 or 0
    local a = self._active
    self._btn.BackgroundColor3 = a and th.AccentDim or th.ElementHover
    Tween(self._btn, t, { BackgroundTransparency = (a or self._hover) and 0 or 1 })
    Tween(self._icon, t, { [self._iconProp] = a and th.Accent or th.SubText })
    Tween(self._label, t, { TextColor3 = a and th.Text or th.SubText })
end

function Tab:Select() self.Window:SelectTab(self) end

function Window:AddTab(opts)
    if type(opts) == "string" then opts = { Name = opts } end
    opts = opts or {}
    local name = opts.Name or ("Tab " .. (#self._tabs + 1))

    local tab = setmetatable({
        Window = self, Name = name, _entries = {}, _order = 0, _active = false, _hover = false,
    }, Tab)

    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), LayoutOrder = #self._tabs + 1, Parent = self._railList,
    })
    Corner(btn, 9)
    local holder = New("Frame", { Size = UDim2.fromOffset(42, 38), BackgroundTransparency = 1, Parent = btn })
    local icon, iconProp
    local ic = opts.Icon
    if type(ic) == "number" or (type(ic) == "string" and ic:find("rbxasset")) then
        local id = type(ic) == "number" and ("rbxassetid://" .. ic) or ic
        icon = New("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18),
            BackgroundTransparency = 1, Image = id, Parent = holder,
        })
        iconProp = "ImageColor3"
    else
        icon = New("TextLabel", {
            Size = UDim2.fromScale(1, 1), Text = ic or string.upper(string.sub(name, 1, 1)), Font = FONT_B,
            TextSize = 16, Parent = holder,
        })
        iconProp = "TextColor3"
    end
    local label = New("TextLabel", {
        Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 1, 0), Text = name, TextXAlignment = LEFT,
        TextTruncate = TRUNCATE, TextTransparency = self._expanded and 0 or 1, Parent = btn,
    })
    tab._btn, tab._icon, tab._iconProp, tab._label = btn, icon, iconProp, label

    local page = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = AUTO_Y, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
        Bind = { ScrollBarImageColor3 = "Accent" }, Parent = self._content,
    })
    Pad(page, 16, 14, 16, 14)
    List(page, 8)
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30), Text = name, Font = FONT_B, TextSize = 20, TextXAlignment = LEFT,
        LayoutOrder = 0, Parent = page,
    })
    tab._page = page
    tab._parent = page

    btn.MouseEnter:Connect(function() tab._hover = true; tab:_paint(true) end)
    btn.MouseLeave:Connect(function() tab._hover = false; tab:_paint(true) end)
    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
    Halcyon:_hook(btn, function() tab:_paint(false) end)

    table.insert(self._tabs, tab)
    if #self._tabs == 1 then self:SelectTab(tab) end
    return tab
end

function Window:SelectTab(tab)
    if type(tab) == "number" then tab = self._tabs[tab] end
    if not tab or self._current == tab then return end
    local prev = self._current
    self._current = tab
    if prev then
        prev._active = false
        prev._page.Visible = false
        prev:_paint(true)
    end
    tab._active = true
    tab:_paint(true)
    tab._page.Visible = true
    tab._page.Position = UDim2.fromOffset(0, 14)
    Tween(tab._page, 0.3, { Position = UDim2.fromOffset(0, 0) })
    if self._searchBox.Text ~= "" then self._searchBox.Text = "" end
    tab:_filter("")
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Window:_connect(sig, fn)
    local c = sig:Connect(fn)
    table.insert(self._conns, c)
    return c
end

function Window:_setRail(open)
    if self._expanded == open then return end
    self._expanded = open
    Tween(self._rail, 0.25, { Size = UDim2.new(0, open and RAIL_OPEN or RAIL_W, 1, 0) })
    for _, t in ipairs(self._tabs) do
        Tween(t._label, 0.2, { TextTransparency = open and 0 or 1 })
    end
    Tween(self._footer, 0.2, { TextTransparency = open and 0 or 1 })
end

function Window:Show()
    self.Visible = true
    self.Orb.Visible = false
    self.Main.Visible = true
    self._scale.Scale = 0.95
    Tween(self._scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Window:Hide()
    if not self.Visible then return end
    self.Visible = false
    Tween(self._scale, 0.15, { Scale = 0.95 })
    task.delay(0.16, function()
        if not self.Visible and self.Main and self.Main.Parent then self.Main.Visible = false end
    end)
end

function Window:Minimize()
    self.Orb.Position = UDim2.fromOffset(self.Main.AbsolutePosition.X + 12, self.Main.AbsolutePosition.Y + 12)
    self:Hide()
    self.Orb.Visible = true
end

function Window:Toggle()
    if self.Visible then self:Hide() else self:Show() end
end

function Window:SetTitle(t)
    self.Title = t
    self._titleLbl.Text = t
end

function Window:SetSubtitle(t)
    self.Subtitle = t
    self._subLbl.Text = t
end

function Window:SetToggleKey(k) self.ToggleKey = k end
function Window:SetTheme(t) Halcyon:SetTheme(t) end
function Window:SetAccent(c) Halcyon:SetAccent(c) end
function Window:Notify(o) return Halcyon:Notify(o) end

function Window:Dialog(opts)
    opts = opts or {}
    local ov = self._overlay
    if self._dialog then self._dialog:Destroy() end
    ov.Visible = true
    Tween(ov, 0.2, { BackgroundTransparency = 0.45 })

    local box = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(opts.Width or 340, 0), AutomaticSize = AUTO_Y,
        Bind = { BackgroundColor3 = "Element" }, Parent = ov,
    })
    Corner(box, 12)
    Stroke(box)
    local sc = New("UIScale", { Scale = 0.9, Parent = box })
    Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
    Pad(box, 18, 16, 18, 16)
    List(box, 10)
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, Text = opts.Title or "Notice", Font = FONT_B, TextSize = 16,
        TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = 1, Parent = box,
    })
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, Text = opts.Content or "", Font = FONT_R, TextSize = 13,
        TextWrapped = true, TextXAlignment = LEFT, LayoutOrder = 2, Bind = { TextColor3 = "SubText" }, Parent = box,
    })
    local row = New("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 3, Parent = box })
    List(row, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local closed = false
    local function close()
        if closed then return end
        closed = true
        Tween(ov, 0.2, { BackgroundTransparency = 1 })
        Tween(sc, 0.15, { Scale = 0.9 })
        task.delay(0.2, function()
            box:Destroy()
            if self._dialog and self._dialog.Parent == nil then self._dialog = nil end
            ov.Visible = false
        end)
    end

    local buttons = opts.Buttons or { { Title = "OK", Primary = true } }
    for i, b in ipairs(buttons) do
        local props = { Size = UDim2.fromOffset(90, 32), LayoutOrder = i, BackgroundTransparency = 0,
            Text = b.Title or "OK", Font = FONT_B, TextSize = 12, Parent = row }
        if b.Primary then
            props.Bind = { BackgroundColor3 = "Accent", TextColor3 = "AccentText" }
        else
            props.Bind = { BackgroundColor3 = "Surface", TextColor3 = "Text" }
        end
        local btn = New("TextButton", props)
        Corner(btn, 8)
        if not b.Primary then Stroke(btn) end
        btn.MouseButton1Click:Connect(function()
            close()
            safe(b.Callback)
        end)
    end
    self._dialog = box
    return { Close = close }
end

-- configs ---------------------------------------------------------------
local function hasFS()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Window:_path(name) return self.Folder .. "/" .. name .. ".json" end

function Window:SaveConfig(name)
    if not hasFS() then return false, "executor has no filesystem functions" end
    if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(self.Folder) then
        pcall(makefolder, self.Folder)
    end
    local ok, err = pcall(writefile, self:_path(name), Halcyon:ExportConfig())
    return ok, err
end

function Window:LoadConfig(name)
    if not hasFS() then return false, "executor has no filesystem functions" end
    local p = self:_path(name)
    if not isfile(p) then return false, "config not found" end
    return Halcyon:ImportConfig(readfile(p))
end

function Window:DeleteConfig(name)
    if type(delfile) == "function" and hasFS() and isfile(self:_path(name)) then
        delfile(self:_path(name))
        return true
    end
    return false
end

function Window:ListConfigs()
    local out = {}
    if type(listfiles) == "function" and type(isfolder) == "function" and isfolder(self.Folder) then
        for _, f in ipairs(listfiles(self.Folder)) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
    end
    table.sort(out)
    return out
end

function Window:HasConfig(name)
    return hasFS() and type(name) == "string" and name ~= "" and isfile(self:_path(name))
end

-- auto-load -------------------------------------------------------------
-- The chosen config name lives in <Folder>/_autoload.txt (not a .json, so it never shows in ListConfigs).
function Window:_autoPath() return self.Folder .. "/_autoload.txt" end

function Window:GetAutoLoad()
    if not hasFS() or not isfile(self:_autoPath()) then return nil end
    local ok, raw = pcall(readfile, self:_autoPath())
    if not ok then return nil end
    local n = tostring(raw):match("^%s*(.-)%s*$")
    if n == "" then return nil end
    return n
end

function Window:SetAutoLoad(name)
    if not hasFS() then return false, "executor has no filesystem functions" end
    if name == nil or name == "" then
        if isfile(self:_autoPath()) then
            if type(delfile) == "function" then
                pcall(delfile, self:_autoPath())
            else
                pcall(writefile, self:_autoPath(), "")
            end
        end
        return true
    end
    if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(self.Folder) then
        pcall(makefolder, self.Folder)
    end
    return pcall(writefile, self:_autoPath(), tostring(name))
end

-- Loads the auto-load config if one is set. Returns ok, nameOrErr. No config set -> false, "no auto-load config".
function Window:RunAutoLoad()
    local n = self:GetAutoLoad()
    if not n then return false, "no auto-load config" end
    local ok, err = self:LoadConfig(n)
    if ok then return true, n end
    return false, err
end

function Window:BuildConfigTab(opts)
    opts = opts or {}
    local win = self
    local tab = self:AddTab({ Name = opts.Name or "Config", Icon = opts.Icon })

    local ui = tab:AddSection({ Title = "Interface" })
    local names = {}
    for n in pairs(Halcyon.Themes) do table.insert(names, n) end
    table.sort(names)
    ui:AddDropdown({
        Title = "Theme", Options = names, Default = Halcyon._themeName or "Midnight",
        Callback = function(v) Halcyon:SetTheme(v) end,
    })
    ui:AddColorPicker({
        Title = "Accent", Default = Halcyon.Theme.Accent,
        Callback = function(c) Halcyon:SetAccent(c) end,
    })
    ui:AddKeybind({
        Title = "Toggle key", Default = self.ToggleKey,
        Callback = function() end,
    }):OnChanged(function(k) win.ToggleKey = k end)

    local cfg = tab:AddSection({ Title = "Configs" })
    local nameBox = cfg:AddInput({ Title = "Config name", Placeholder = "default" })
    local dd = cfg:AddDropdown({ Title = "Saved configs", Options = self:ListConfigs(), Placeholder = "none" })
    local function pick()
        local n = nameBox:Get()
        if n == "" then n = dd:Get() or "" end
        return n
    end
    cfg:AddButton({ Title = "Save", Callback = function()
        local n = pick()
        if n == "" then Halcyon:Notify({ Title = "Config", Content = "Enter a name first.", Type = "Warning" }) return end
        local ok, err = win:SaveConfig(n)
        dd:Refresh(win:ListConfigs(), true)
        Halcyon:Notify({ Title = "Config", Content = ok and ("Saved " .. n) or tostring(err), Type = ok and "Success" or "Error" })
    end })
    cfg:AddButton({ Title = "Load", Callback = function()
        local n = pick()
        local ok, err = win:LoadConfig(n)
        Halcyon:Notify({ Title = "Config", Content = ok and ("Loaded " .. n) or tostring(err), Type = ok and "Success" or "Error" })
    end })
    local auto
    local function autoDesc()
        local cur = win:GetAutoLoad()
        return cur and ("Loads \"" .. cur .. "\" on startup") or "Off"
    end
    cfg:AddButton({ Title = "Delete", Callback = function()
        local n = pick()
        local ok = win:DeleteConfig(n)
        if ok and n == win:GetAutoLoad() then
            win:SetAutoLoad(nil)
            auto:Set(false, true)
            auto:SetDesc(autoDesc())
        end
        dd:Refresh(win:ListConfigs(), false)
        Halcyon:Notify({ Title = "Config", Content = ok and ("Deleted " .. n) or "Nothing deleted", Type = ok and "Success" or "Warning" })
    end })
    cfg:AddButton({ Title = "Refresh list", Callback = function() dd:Refresh(win:ListConfigs(), true) end })

    auto = cfg:AddToggle({
        Title = "Auto-load config", Desc = autoDesc(), Default = win:GetAutoLoad() ~= nil,
        Callback = function(on)
            if not on then
                win:SetAutoLoad(nil)
                auto:SetDesc(autoDesc())
                return
            end
            local n = pick()
            if n == "" then
                auto:Set(false, true)
                Halcyon:Notify({ Title = "Auto-load", Content = "Pick or type a config name first.", Type = "Warning" })
                return
            end
            if not win:HasConfig(n) then
                auto:Set(false, true)
                Halcyon:Notify({ Title = "Auto-load", Content = "Save \"" .. n .. "\" first.", Type = "Warning" })
                return
            end
            local ok, err = win:SetAutoLoad(n)
            if not ok then
                auto:Set(false, true)
                Halcyon:Notify({ Title = "Auto-load", Content = tostring(err), Type = "Error" })
                return
            end
            auto:SetDesc(autoDesc())
            Halcyon:Notify({ Title = "Auto-load", Content = "\"" .. n .. "\" loads on startup.", Type = "Success" })
        end,
    })

    -- Deferred so the rest of the script finishes creating its elements before the config is applied.
    if opts.AutoLoad ~= false and win:GetAutoLoad() then
        task.defer(function()
            if not win.Main or not win.Main.Parent then return end
            local ok, res = win:RunAutoLoad()
            Halcyon:Notify({
                Title = "Auto-load", Content = ok and ("Loaded " .. res) or tostring(res),
                Type = ok and "Success" or "Warning",
            })
        end)
    end
    return tab
end

function Window:Destroy()
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self._conns = {}
    for flag, el in pairs(self._flags) do
        if Halcyon.Flags[flag] == el then Halcyon.Flags[flag] = nil end
    end
    if self.Main then self.Main:Destroy() end
    if self.Orb then self.Orb:Destroy() end
    for i, w in ipairs(Halcyon.Windows) do
        if w == self then
            table.remove(Halcyon.Windows, i)
            break
        end
    end
end

function Halcyon:CreateWindow(opts)
    opts = opts or {}
    local gui = self:_ensureGui()
    if opts.Theme then self:SetTheme(opts.Theme) end
    if opts.Accent then self:SetAccent(opts.Accent) end

    local win = setmetatable({}, Window)
    win.Library = self
    win.Title = opts.Title or "Halcyon"
    win.Subtitle = opts.Subtitle or ""
    win.Folder = opts.Folder or "Halcyon"
    win.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
    win.Visible = true
    win._conns, win._tabs, win._flags = {}, {}, {}
    win._expanded, win._pinned = false, false
    table.insert(self.Windows, win)

    local vp = viewport()
    local size = opts.Size or UDim2.fromOffset(640, 430)
    local w = math.min(size.X.Offset, math.max(vp.X - 24, 320))
    local h = math.min(size.Y.Offset, math.max(vp.Y - 24, 260))
    local minSize = opts.MinSize or Vector2.new(480, 320)

    -- main ----------------------------------------------------------------
    local main = New("Frame", {
        Name = "Main", Position = UDim2.fromOffset(math.floor((vp.X - w) / 2), math.floor((vp.Y - h) / 2)),
        Size = UDim2.fromOffset(w, h), Bind = { BackgroundColor3 = "Background" }, Parent = gui,
    })
    Corner(main, 12)
    win.Main = main
    win._scale = New("UIScale", { Scale = 1, Parent = main })
    local border = New("UIStroke", { Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = main })
    local grad = New("UIGradient", { Parent = border })
    self:_hook(main, function(th)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, th.Accent),
            ColorSequenceKeypoint.new(0.5, th.Stroke),
            ColorSequenceKeypoint.new(1, th.Accent),
        })
    end)
    if opts.AnimatedBorder ~= false then
        win:_connect(RunService.Heartbeat, function()
            if win.Visible then grad.Rotation = (os.clock() * 25) % 360 end
        end)
    end

    -- topbar ----------------------------------------------------------------
    local top = New("Frame", { Name = "Topbar", Size = UDim2.new(1, 0, 0, TOP), Bind = { BackgroundColor3 = "Surface" }, Parent = main })
    Corner(top, 12)
    New("Frame", { Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0.5, 0), Bind = { BackgroundColor3 = "Surface" }, Parent = top })
    New("Frame", { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Bind = { BackgroundColor3 = "Stroke" }, Parent = top })
    local dragHandle = New("TextButton", { Size = UDim2.fromScale(1, 1), Parent = top })

    local menuBtn = New("TextButton", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(12, 7), Parent = top })
    Corner(menuBtn, 8)
    for i = 0, 2 do
        New("Frame", {
            Size = UDim2.fromOffset(14, 2), Position = UDim2.fromOffset(9, 10 + i * 5),
            Bind = { BackgroundColor3 = "SubText" }, Parent = menuBtn,
        })
    end
    HoverBtn(menuBtn)

    local titleWrap = New("Frame", {
        Position = UDim2.fromOffset(54, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = AUTO_X,
        BackgroundTransparency = 1, Parent = top,
    })
    List(titleWrap, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
    win._titleLbl = New("TextLabel", {
        Size = UDim2.new(0, 0, 0, 20), AutomaticSize = AUTO_X, Text = win.Title, Font = FONT_B, TextSize = 14,
        LayoutOrder = 1, Parent = titleWrap,
    })
    win._subLbl = New("TextLabel", {
        Size = UDim2.new(0, 0, 0, 20), AutomaticSize = AUTO_X, Text = win.Subtitle, Font = FONT_R, TextSize = 12,
        LayoutOrder = 2, Bind = { TextColor3 = "SubText" }, Parent = titleWrap,
    })

    local closeBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(28, 28),
        Text = "\u{00D7}", TextSize = 20, Parent = top,
    })
    Corner(closeBtn, 8)
    HoverBtn(closeBtn, "Danger")
    local minBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -42, 0.5, 0), Size = UDim2.fromOffset(28, 28),
        Text = "-", TextSize = 18, Font = FONT_B, Parent = top,
    })
    Corner(minBtn, 8)
    HoverBtn(minBtn)

    local searchWrap = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -78, 0.5, 0), Size = UDim2.fromOffset(160, 28),
        Bind = { BackgroundColor3 = "Element" }, Parent = top,
    })
    Corner(searchWrap, 8)
    local searchStroke = Stroke(searchWrap)
    win._searchBox = New("TextBox", {
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), PlaceholderText = "Search\u{2026}",
        ClearTextOnFocus = false, TextSize = 12, TextXAlignment = LEFT, Bind = { PlaceholderColor3 = "SubText" },
        Parent = searchWrap,
    })
    win._searchBox.Focused:Connect(function() Tween(searchStroke, 0.15, { Color = Halcyon.Theme.Accent }) end)
    win._searchBox.FocusLost:Connect(function() Tween(searchStroke, 0.15, { Color = Halcyon.Theme.Stroke }) end)
    win._searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        if win._current then win._current:_filter(win._searchBox.Text:lower()) end
    end)

    -- body ------------------------------------------------------------------
    local body = New("Frame", {
        Name = "Body", Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -TOP),
        BackgroundTransparency = 1, Parent = main,
    })
    win._content = New("Frame", {
        Name = "Content", Position = UDim2.fromOffset(RAIL_W, 0), Size = UDim2.new(1, -RAIL_W, 1, 0),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = body,
    })
    local rail = New("Frame", {
        Name = "Rail", Size = UDim2.new(0, RAIL_W, 1, 0), ClipsDescendants = true, ZIndex = 5,
        Bind = { BackgroundColor3 = "Surface" }, Parent = body,
    })
    Corner(rail, 12)
    New("Frame", { Size = UDim2.new(1, 0, 0, 14), Bind = { BackgroundColor3 = "Surface" }, Parent = rail })
    New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 14, 1, 0), Bind = { BackgroundColor3 = "Surface" }, Parent = rail })
    New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0), Bind = { BackgroundColor3 = "Stroke" }, Parent = rail })
    win._rail = rail
    win._railList = New("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1,
        ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = AUTO_Y, Parent = rail,
    })
    Pad(win._railList, 6, 0, 6, 0)
    List(win._railList, 4)
    win._footer = New("TextLabel", {
        Position = UDim2.new(0, 16, 1, -30), Size = UDim2.new(1, -16, 0, 20),
        Text = "HALCYON  v" .. Halcyon.Version, Font = FONT_B, TextSize = 10, TextXAlignment = LEFT, TextTransparency = 1,
        Bind = { TextColor3 = "SubText" }, Parent = rail,
    })

    -- resize grip ------------------------------------------------------------
    local grip = New("TextButton", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), Size = UDim2.fromOffset(18, 18), ZIndex = 20, Parent = main,
    })
    for i = 1, 2 do
        local len = i == 1 and 12 or 6
        New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, i == 1 and -9 or -5, 1, i == 1 and -9 or -5),
            Size = UDim2.fromOffset(len, 2), Rotation = -45, ZIndex = 21, Bind = { BackgroundColor3 = "SubText" }, Parent = grip,
        })
    end
    local gStart, gSize
    BindDrag(win, grip, function(p)
        gStart = p
        gSize = main.AbsoluteSize
    end, function(p)
        if not gStart then return end
        local d = p - gStart
        local v = viewport()
        local nw = math.clamp(gSize.X + d.X, minSize.X, math.max(v.X - main.AbsolutePosition.X, minSize.X))
        local nh = math.clamp(gSize.Y + d.Y, minSize.Y, math.max(v.Y - main.AbsolutePosition.Y, minSize.Y))
        main.Size = UDim2.fromOffset(nw, nh)
    end)

    -- overlay (dialogs) -------------------------------------------------------
    win._overlay = New("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        Visible = false, Active = true, ZIndex = 40, Parent = main,
    })
    Corner(win._overlay, 12)

    -- orb (minimized state) ---------------------------------------------------
    local orb = New("TextButton", {
        Name = "Orb", Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(24, 120),
        Text = string.upper(string.sub(win.Title, 1, 1)), Font = FONT_B, TextSize = 18, BackgroundTransparency = 0,
        Visible = false, Bind = { BackgroundColor3 = "Accent", TextColor3 = "AccentText" }, Parent = gui,
    })
    Corner(orb, 23)
    New("UIStroke", { Thickness = 3, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Bind = { Color = "Accent" }, Parent = orb })
    win.Orb = orb
    local oStart, oPos, oMoved
    BindDrag(win, orb, function(p)
        oStart, oPos, oMoved = p, orb.Position, false
    end, function(p)
        local d = p - oStart
        if d.Magnitude > 5 then oMoved = true end
        if oMoved then
            Tween(orb, 0.05, { Position = UDim2.fromOffset(oPos.X.Offset + d.X, oPos.Y.Offset + d.Y) })
        end
    end, function()
        if not oMoved then win:Show() end
    end)

    -- window drag ---------------------------------------------------------------
    local dPointer, dPos
    BindDrag(win, dragHandle, function(p)
        dPointer, dPos = p, main.Position
    end, function(p)
        if not dPointer then return end
        local v = viewport()
        local d = p - dPointer
        local x = math.clamp(dPos.X.Offset + d.X, -main.AbsoluteSize.X + 90, v.X - 90)
        local y = math.clamp(dPos.Y.Offset + d.Y, 0, v.Y - 40)
        Tween(main, 0.07, { Position = UDim2.fromOffset(x, y) }, Enum.EasingStyle.Quad)
    end)

    -- buttons -------------------------------------------------------------------
    closeBtn.MouseButton1Click:Connect(function() win:Destroy() end)
    minBtn.MouseButton1Click:Connect(function() win:Minimize() end)
    menuBtn.MouseButton1Click:Connect(function()
        win._pinned = not win._pinned
        win:_setRail(win._pinned)
    end)

    -- rail hover ----------------------------------------------------------------
    rail.MouseEnter:Connect(function()
        if main.Visible then win:_setRail(true) end
    end)
    win:_connect(UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if not win.Visible or win._pinned or not win._expanded then return end
        local p = UserInputService:GetMouseLocation()
        local rp, rs = rail.AbsolutePosition, rail.AbsoluteSize
        local loose = p.X >= rp.X - 4 and p.X <= rp.X + RAIL_OPEN + 4 and p.Y >= rp.Y - 40 and p.Y <= rp.Y + rs.Y + 40
        if not loose then win:_setRail(false) end
    end)
    win:_connect(UserInputService.InputChanged, function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if not win.Visible or win._pinned or win._expanded then return end
        local p = UserInputService:GetMouseLocation()
        local rp, rs = rail.AbsolutePosition, rail.AbsoluteSize
        if p.X >= rp.X and p.X <= rp.X + RAIL_W and p.Y >= rp.Y and p.Y <= rp.Y + rs.Y then win:_setRail(true) end
    end)

    -- toggle key ------------------------------------------------------------------
    win:_connect(UserInputService.InputBegan, function(input, gpe)
        if gpe or Halcyon._listening then return end
        if input.KeyCode == win.ToggleKey then win:Toggle() end
    end)

    env.__Halcyon = self
    main.Visible = true
    win._scale.Scale = 0.95
    Tween(win._scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
    return win
end

Halcyon.Icons = nil -- icons are plain text glyphs or rbxassetid values; see docs

env.__Halcyon = Halcyon
return Halcyon
