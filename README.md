# Halcyon

documentation:

# Halcyon — Documentation

Halcyon is a Roblox UI library for script executors. Everything is built from plain `Instance`s, uses no external assets, and runs on `gethui()` / `CoreGui` / `PlayerGui` (whichever your executor allows).

What makes it different:

- **Hover-expanding icon rail** instead of a fixed sidebar. It sits over the content, so the page never reflows. Pin it with the menu button (≡), which is also the touch-friendly way to open it.
- **Minimize to orb.** The `-` button collapses the window into a draggable orb. Click the orb to restore it.
- **Animated gradient border** that follows the theme.
- **Search** in the top bar filters the elements of the current tab (collapsed sections are opened while searching).
- **Inline dropdowns and color pickers.** They expand inside their card, with no floating popups to clip or z-fight.
- Live theme and accent switching, resizable window, notifications, dialogs, flags, and JSON configs.

> Status: syntax-checked only. It has not been run inside a Roblox client or an executor. If something misbehaves on your executor, the most likely suspects are pointer coordinates (inset handling) and `gethui`.

---

## 1. Loading

```lua
local Halcyon = loadstring(readfile("Halcyon.lua"))()
-- or host it and:
-- local Halcyon = loadstring(game:HttpGet("https://your.host/Halcyon.lua"))()
```

Re-executing the script destroys the previous Halcyon instance first, so you never get duplicate windows.

## 2. Quick start

```lua
local Halcyon = loadstring(readfile("Halcyon.lua"))()

local Window = Halcyon:CreateWindow({
    Title     = "My Hub",
    Subtitle  = "v1.0",
    Theme     = "Midnight",
    ToggleKey = Enum.KeyCode.RightShift,
    Folder    = "MyHub",
})

local Main = Window:AddTab({ Name = "Main", Icon = "M" })

local Sec = Main:AddSection({ Title = "Movement" })

Sec:AddToggle({
    Title = "Speed boost", Desc = "Overrides WalkSpeed", Flag = "SpeedOn",
    Callback = function(on) print("speed", on) end,
})

Sec:AddSlider({
    Title = "WalkSpeed", Min = 16, Max = 120, Default = 16, Suffix = " sps", Flag = "Speed",
    Callback = function(v) print(v) end,
})

Window:BuildConfigTab()
Halcyon:Notify({ Title = "Loaded", Content = "Press RightShift to toggle.", Type = "Success" })
```

---

## 3. Library API (`Halcyon`)

| Member | Description |
|---|---|
| `Halcyon:CreateWindow(opts)` | Creates a window. Returns a **Window**. See section 4. |
| `Halcyon:Notify(opts)` | Shows a toast. See section 9. |
| `Halcyon:SetTheme(nameOrTable)` | Switches theme live for every window. Resets any accent override. |
| `Halcyon:SetAccent(Color3)` | Overrides the accent color of the current theme. |
| `Halcyon:AddTheme(name, table)` | Registers a custom theme. Missing keys fall back to Midnight. |
| `Halcyon:ExportConfig()` | Returns a JSON string of every element that has a `Flag`. |
| `Halcyon:ImportConfig(json)` | Applies a JSON string. Returns `true`, or `false, err`. |
| `Halcyon:GetFlag(name)` | Returns the current value of a flagged element, or `nil`. |
| `Halcyon.Flags` | Table `{ [flag] = element }`. Use `Halcyon.Flags.Speed:Get()`. |
| `Halcyon.Themes` | Table of registered themes. |
| `Halcyon.Windows` | Array of live windows. |
| `Halcyon:Destroy()` | Removes every window, toast and the ScreenGui. |
| `Halcyon.Version` | Version string. |

---

## 4. Window

### `Halcyon:CreateWindow(opts)`

| Option | Type | Default | Notes |
|---|---|---|---|
| `Title` | string | `"Halcyon"` | Shown in the top bar. Its first letter is used on the minimize orb. |
| `Subtitle` | string | `""` | Dim text next to the title. |
| `Size` | UDim2 | `UDim2.fromOffset(640, 430)` | Only the **offset** is read. Clamped to the screen. |
| `MinSize` | Vector2 | `Vector2.new(480, 320)` | Minimum size when resizing from the bottom-right grip. |
| `Theme` | string / table | `"Midnight"` | `Midnight`, `Ember`, `Moss`, `Paper`, or a custom table. |
| `Accent` | Color3 | theme accent | Overrides the accent. |
| `ToggleKey` | Enum.KeyCode | `RightShift` | Show/hide the window. |
| `Folder` | string | `"Halcyon"` | Folder used by config save/load. |
| `AnimatedBorder` | boolean | `true` | Rotating gradient border. Set `false` to save a little CPU. |

### Window methods

| Method | Description |
|---|---|
| `Window:AddTab(opts)` | Creates a tab. Returns a **Tab**. |
| `Window:SelectTab(tabOrIndex)` | Selects a tab by object or 1-based index. |
| `Window:Show()` / `:Hide()` / `:Toggle()` | Visibility. |
| `Window:Minimize()` | Collapses to the orb. |
| `Window:SetTitle(str)` / `:SetSubtitle(str)` | Update the header text. |
| `Window:SetToggleKey(Enum.KeyCode)` | Rebind the toggle key. |
| `Window:SetTheme(nameOrTable)` / `:SetAccent(Color3)` | Same as the library functions. |
| `Window:Notify(opts)` | Alias of `Halcyon:Notify`. |
| `Window:Dialog(opts)` | Modal dialog. See section 10. |
| `Window:SaveConfig(name)` | Writes `<Folder>/<name>.json`. Returns `ok, err`. |
| `Window:LoadConfig(name)` | Loads a config. Returns `ok, err`. |
| `Window:DeleteConfig(name)` | Deletes a config. Returns a boolean. |
| `Window:ListConfigs()` | Returns an array of saved config names. |
| `Window:BuildConfigTab(opts)` | Builds a ready-made Config tab (theme, accent, toggle key, save/load/delete). `opts.Name` (default `"Config"`), `opts.Icon`. |
| `Window:Destroy()` | Removes this window and its connections. |

Window interactions:

- Drag the top bar to move.
- Drag the bottom-right grip to resize.
- `-` minimizes to the orb; `×` destroys the window.
- Hover the left rail, or click ≡, to show tab names.

---

## 5. Tabs

### `Window:AddTab(opts)`

`opts` can be a string (the tab name) or a table:

| Option | Type | Notes |
|---|---|---|
| `Name` | string | Tab name. Also used as the page heading. |
| `Icon` | string / number | Optional. A text glyph (`"M"`, `"@"`), an `rbxassetid://` string, or a numeric asset id. If omitted, the first letter of `Name` is used. |

Icons are plain text by default because glyph coverage in Roblox fonts varies by platform. Stick to ASCII or characters you have tested.

A tab exposes every element method from section 7 directly. Elements added to a tab appear in order. A tab also has `Tab:AddSection(...)`, `Tab:Select()`, and `Tab.Name`.

---

## 6. Sections

```lua
local sec = Tab:AddSection({ Title = "Combat", Open = true })
```

| Option | Type | Default | Notes |
|---|---|---|---|
| `Title` | string | `"Section"` | Rendered upper-case with a divider line. |
| `Open` | boolean | `true` | Initial collapsed state. |

Sections have all the element methods from section 7, plus:

| Method | Description |
|---|---|
| `Section:SetOpen(bool)` / `:Toggle()` | Expand or collapse. |
| `Section:SetTitle(str)` | Rename. |
| `Section:Destroy()` | Remove the section and its elements. |

Clicking the header toggles it. Sections are added to a Tab. Nesting a section inside another section is allowed by the code but untested.

---

## 7. Elements

All elements share these methods:

| Method | Description |
|---|---|
| `el:Get()` | Current value. |
| `el:OnChanged(fn)` | Add an extra listener. Returns the element. |
| `el:SetVisible(bool)` | Show or hide the element. |
| `el:SetTitle(str)` / `el:SetDesc(str)` | Update the text. |
| `el:Destroy()` | Remove the element. |

Common options on every element:

| Option | Notes |
|---|---|
| `Title` | Main label. |
| `Desc` | Optional second line in a dimmer color. |
| `Flag` | Registers the element in `Halcyon.Flags[flag]` and includes it in configs. |
| `Callback` | Called when the value changes. |
| `FireOnCreate` | On value elements: also fire the callback once at creation with the default. |

Callbacks run in `task.spawn` with `pcall`, so an error in one never breaks the UI (it is `warn`ed instead).

### Button

```lua
Tab:AddButton({ Title = "Rejoin", Desc = "Teleports to a fresh server", Callback = function() end })
-- or Tab:AddButton("Click me")
```

Callback: `function() end`. Extra method: `el:Fire()` runs the callback.

### Toggle

```lua
local t = Tab:AddToggle({ Title = "ESP", Default = false, Flag = "ESP", Callback = function(on) end })
```

| Option | Type | Default |
|---|---|---|
| `Default` | boolean | `false` |

Methods: `el:Set(bool, silent)`, `el:Toggle()`. When `silent` is true the callback is not fired.

### Slider

```lua
Tab:AddSlider({ Title = "FOV", Min = 30, Max = 120, Default = 70, Increment = 1, Suffix = "°", Flag = "FOV",
    Callback = function(v) end })
```

| Option | Type | Default |
|---|---|---|
| `Min`, `Max` | number | `0`, `100` |
| `Default` | number | `Min` |
| `Increment` | number | `1` (decimal places are derived from it, e.g. `0.1`) |
| `Suffix` | string | `""` |

Drag the track, or click the value box and type a number. Methods: `el:Set(number, silent)`.

### Input

```lua
Tab:AddInput({ Title = "Target", Placeholder = "name", Default = "", Numeric = false, Live = false, Width = 150,
    Flag = "Target", Callback = function(text) end })
```

| Option | Type | Default | Notes |
|---|---|---|---|
| `Default` | string | `""` | |
| `Placeholder` | string | `""` | |
| `Numeric` | boolean | `false` | Strips everything except digits, `.` and `-`. |
| `Live` | boolean | `false` | Fire on every keystroke instead of when focus is lost. |
| `Width` | number | `150` | Box width in pixels. |

Methods: `el:Set(text, silent)`.

### Dropdown

```lua
local dd = Tab:AddDropdown({ Title = "Mode", Options = { "Legit", "Rage" }, Default = "Legit", Flag = "Mode",
    Callback = function(v) end })

local multi = Tab:AddDropdown({ Title = "Parts", Options = { "Head", "Torso", "Legs" }, Multi = true,
    Default = { "Head" }, Callback = function(list) end })
```

| Option | Type | Default | Notes |
|---|---|---|---|
| `Options` | array | `{}` | Values are converted with `tostring`. |
| `Default` | string or array | none | Array when `Multi = true`. |
| `Multi` | boolean | `false` | Value is an array of selected options, in option order. |
| `MaxRows` | number | `6` | Visible rows before the list scrolls. |
| `Placeholder` | string | `"Select"` / `"None"` | Shown when nothing is selected. |

Methods:

| Method | Description |
|---|---|
| `el:Set(valueOrArray, silent)` | Select programmatically. Unknown options are ignored. |
| `el:Get()` | String, or a copy of the array when `Multi`. |
| `el:Refresh(newOptions, keepSelection)` | Replace the options. With `keepSelection = true`, still-valid selections are kept. |
| `el:Open()` / `el:Close()` | Expand or collapse the list. |

### Keybind

```lua
Tab:AddKeybind({ Title = "Fly", Default = Enum.KeyCode.F, Mode = "Press", Flag = "FlyKey",
    Callback = function(key) end })

Tab:AddKeybind({ Title = "Aim hold", Default = "E", Mode = "Hold",
    Callback = function(isDown) end })
```

| Option | Type | Default | Notes |
|---|---|---|---|
| `Default` | Enum.KeyCode or string | none | A string is looked up in `Enum.KeyCode`, e.g. `"F"`. |
| `Mode` | `"Press"` / `"Hold"` | `"Press"` | `Press` calls `Callback(keyCode)`. `Hold` calls `Callback(true)` on press and `Callback(false)` on release. |

Click the button, then press a key to rebind; `Escape` clears the bind (`None`). `Callback` is the **trigger** callback. Use `el:OnChanged(fn)` to react to rebinding (receives the new `Enum.KeyCode`).

Methods: `el:Set(keyCodeOrName, silent)`, `el:IsDown()` (Hold mode). Keybinds ignore input while you are typing in a text box.

### ColorPicker

```lua
Tab:AddColorPicker({ Title = "ESP color", Default = Color3.fromRGB(255, 80, 80), Flag = "ESPColor",
    Callback = function(c) end })
```

Click the card to expand a saturation/value square, a hue bar, and a hex box (`#RRGGBB`).

Methods: `el:Set(Color3, silent)`, `el:Get()` returns a `Color3`, `el:GetHex()` returns `"#RRGGBB"`.

### Label

```lua
local l = Tab:AddLabel("Plain dim text")      -- or { Text = "..." }
l:SetText("Updated")
```

### Paragraph

```lua
local p = Tab:AddParagraph({ Title = "About", Content = "Longer wrapped text goes here." })
p:SetContent("New text")
```

### Divider

```lua
Tab:AddDivider()
```

---

## 8. Flags and configs

Give an element a `Flag` and it becomes readable from anywhere and saved in configs:

```lua
Tab:AddToggle({ Title = "Auto farm", Flag = "AutoFarm" })

while task.wait(0.5) do
    if Halcyon.Flags.AutoFarm and Halcyon.Flags.AutoFarm.Value then
        -- ...
    end
end
```

Saved formats:

- Toggle, Slider, Input: plain JSON value.
- Dropdown: string, or array when `Multi`.
- ColorPicker: `{ "__color": "#RRGGBB" }`.
- Keybind: `{ "__key": "F" }`.

Config files are written to `<workspace>/<Folder>/<name>.json`. This needs `writefile`, `readfile` and `isfile`; `makefolder`, `isfolder`, `listfiles` and `delfile` are used when available. When filesystem functions are missing, `SaveConfig` returns `false, "executor has no filesystem functions"`.

`Halcyon:ExportConfig()` / `Halcyon:ImportConfig(json)` work without a filesystem, so you can copy and paste a config string.

`Window:BuildConfigTab()` gives you a finished UI for all of this, plus theme, accent, and toggle-key controls.

---

## 9. Notifications

```lua
Halcyon:Notify({
    Title    = "Saved",
    Content  = "Config written.",
    Duration = 4,
    Type     = "Success",
})
-- Halcyon:Notify("short text")
```

| Option | Type | Default | Notes |
|---|---|---|---|
| `Title` | string | the `Type` | |
| `Content` | string | none | Wraps automatically. |
| `Duration` | number | `4` | Seconds. `0` makes the toast sticky until clicked. |
| `Type` | string | `"Info"` | `Info` (uses the accent), `Success`, `Warning`, `Error`. |

Click a toast to dismiss it. Returns a handle with `:Close()`.

---

## 10. Dialogs

```lua
Window:Dialog({
    Title   = "Reset settings?",
    Content = "This cannot be undone.",
    Buttons = {
        { Title = "Cancel" },
        { Title = "Reset", Primary = true, Callback = function() print("reset") end },
    },
})
```

| Option | Type | Default |
|---|---|---|
| `Title` | string | `"Notice"` |
| `Content` | string | `""` |
| `Width` | number | `340` |
| `Buttons` | array of `{ Title, Primary, Callback }` | one `OK` button |

The dialog dims the window and closes itself when a button is pressed. Returns a handle with `:Close()`.

---

## 11. Themes

Built in: `Midnight` (default), `Ember`, `Moss`, `Paper` (light).

```lua
Halcyon:SetTheme("Ember")
Halcyon:SetAccent(Color3.fromRGB(255, 90, 160))

Halcyon:AddTheme("Ocean", {
    Background   = Color3.fromRGB(10, 16, 24),
    Surface      = Color3.fromRGB(14, 22, 33),
    Element      = Color3.fromRGB(20, 31, 46),
    ElementHover = Color3.fromRGB(27, 41, 60),
    Stroke       = Color3.fromRGB(37, 56, 80),
    Text         = Color3.fromRGB(226, 238, 250),
    SubText      = Color3.fromRGB(122, 146, 172),
    Accent       = Color3.fromRGB(64, 196, 255),
    Track        = Color3.fromRGB(38, 58, 82),
})
Halcyon:SetTheme("Ocean")
```

Theme keys: `Background`, `Surface`, `Element`, `ElementHover`, `Stroke`, `Text`, `SubText`, `Accent`, `Track`. `AccentDim` (selected-item tint), `AccentText` (text color on accent surfaces) and `Danger` are derived automatically.

---

## 12. Behaviour notes

- **Hotkeys** are ignored when the game has already processed the input (typing in chat, a text box, and so on). While a Keybind is waiting for a key, the window toggle key is suppressed.
- **Mobile / touch:** dragging, sliders and pickers accept touch input. Use the ≡ button to expand the rail, and the orb to restore a minimized window.
- **GUI parent:** `gethui()` if available, else `CoreGui`, else `PlayerGui`. The ScreenGui gets a random GUID name. `syn.protect_gui` is called when it exists.
- **Search** only affects the current tab, and is cleared whenever you switch tabs.
- **Errors in callbacks** never propagate into the library; you will see `[Halcyon] callback error: ...` in the console.

## 13. Full example

```lua
local Halcyon = loadstring(readfile("Halcyon.lua"))()
local Window = Halcyon:CreateWindow({ Title = "Demo", Subtitle = "Halcyon", Folder = "DemoHub" })

local Home = Window:AddTab({ Name = "Home", Icon = "H" })
Home:AddParagraph({ Title = "Welcome", Content = "Hover the left rail to see tab names." })
Home:AddButton({ Title = "Say hi", Callback = function()
    Halcyon:Notify({ Title = "Hi", Content = "Button pressed", Type = "Info" })
end })

local Vis = Window:AddTab({ Name = "Visuals", Icon = "V" })
local esp = Vis:AddSection({ Title = "ESP" })
esp:AddToggle({ Title = "Enabled", Flag = "ESP", Callback = function(v) print("ESP", v) end })
esp:AddColorPicker({ Title = "Color", Default = Color3.fromRGB(255, 70, 70), Flag = "ESPColor" })
esp:AddDropdown({ Title = "Parts", Options = { "Head", "Torso", "Legs" }, Multi = true, Default = { "Head" }, Flag = "Parts" })
esp:AddSlider({ Title = "Max distance", Min = 100, Max = 2000, Default = 800, Increment = 50, Suffix = " st", Flag = "Dist" })
esp:AddKeybind({ Title = "Toggle key", Default = Enum.KeyCode.G, Callback = function()
    Halcyon.Flags.ESP:Toggle()
end })

Window:BuildConfigTab()
