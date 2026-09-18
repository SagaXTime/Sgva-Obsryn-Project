-- SGVA BLOX FRUITS HUB v8
-- DEVELOPER: SAGA
-- Fix v8: Melee VIM fallback, AutoRaid HP filter, AutoQuest cycle

print("[SGVA-BF] SCRIPT START v8")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local HasMouse1Click = (mouse1click ~= nil)
local HasMouse1Press = (mouse1press ~= nil)
local HasMouse1Release = (mouse1release ~= nil)

local GlobalEnv = (function()
    if getgenv then
        local ok, env = pcall(getgenv)
        if ok and env then return env end
    end
    return _G
end)()

if GlobalEnv.SGVA_BF_Cleanup then
    pcall(GlobalEnv.SGVA_BF_Cleanup)
end

local function LogErr(tag, err)
    warn("[SGVA-BF]", tag, err)
end

local function GetUIParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui and typeof(hui) == "Instance" then return hui end
    end
    if get_hidden_gui then
        local ok, hgui = pcall(get_hidden_gui)
        if ok and hgui and typeof(hgui) == "Instance" then return hgui end
    end
    local CoreGui = game:GetService("CoreGui")
    if CoreGui then
        local ok = pcall(function()
            local t = Instance.new("Folder")
            t.Parent = CoreGui
            t:Destroy()
        end)
        if ok then return CoreGui end
    end
    return LocalPlayer:WaitForChild("PlayerGui", 10)
end

local UIParent = GetUIParent()
if not UIParent then LogErr("Init", "No UI parent") return end

for _, parent in ipairs({
    game:GetService("CoreGui"),
    LocalPlayer:FindFirstChild("PlayerGui"),
    UIParent
}) do
    if parent then
        local old = parent:FindFirstChild("SGVA_BLOX_FRUITS")
        if old then old:Destroy() end
    end
end

local Theme = {
    Background = Color3.fromRGB(8, 12, 24),
    Header = Color3.fromRGB(12, 18, 36),
    Panel = Color3.fromRGB(14, 22, 42),
    PanelLight = Color3.fromRGB(20, 30, 54),
    PanelAccent = Color3.fromRGB(26, 40, 68),
    Accent = Color3.fromRGB(60, 130, 255),
    AccentGlow = Color3.fromRGB(100, 180, 255),
    AccentDark = Color3.fromRGB(30, 70, 160),
    Green = Color3.fromRGB(0, 220, 130),
    Red = Color3.fromRGB(255, 70, 90),
    Text = Color3.fromRGB(230, 240, 255),
    TextDim = Color3.fromRGB(130, 150, 190),
    TextDark = Color3.fromRGB(80, 100, 140),
    Divider = Color3.fromRGB(30, 45, 75),
    ToggleOn = Color3.fromRGB(60, 130, 255),
    ToggleOff = Color3.fromRGB(30, 40, 60)
}

local State = {
    AutoFarm = false, AutoChest = false, AutoBone = false,
    AutoMastery = false, AutoQuest = false, KillAura = false, BringMob = false,
    SearchRadius = 300, FarmOffset = 18, AttackDelay = 0.15, TweenSpeed = 250,
    BringRadius = 350, AutoFarmMode = "Nearest", SelectedWeapon = "Melee",
    FruitSniper = false, AutoStoreFruit = false, ESPFruit = false,
    SelectedFruit = "None",
    AutoRaid = false, KillAllRaid = false, AutoNextIsland = false,
    RaidChip = "Flame", RaidState = "idle", RaidLastCheck = 0, RaidSnapshot = nil,
    RaidMinHealth = 1000,
    QuestState = "idle", QuestLastCheck = 0,
    AutoFish = false, SeaBeastFarm = false,
    ESPPlayer = false, ESPEnemy = false, Noclip = false,
    Fly = false, FlySpeed = 80,
    FastWalk = false, WalkSpeed = 50,
    MoonJump = false, JumpPower = 150,
    AntiAFK = true, FPSBoost = false, FPSBoostActive = false,
    Destroyed = false, UserHasDragged = false, ActiveTab = "Farm",
    CreditsPopup = nil,
    Connections = {},
    BaseWalkSpeed = 16, BaseJumpPower = 50,
    SearchText = "",
    ActiveFarmTarget = nil,
    ActiveDropdown = nil,
    MeleeWarnShown = false
}

local function AddConnection(name, signal, cb)
    if not signal then return nil end
    if State.Connections[name] then
        pcall(function() State.Connections[name]:Disconnect() end)
    end
    State.Connections[name] = signal:Connect(cb)
    return State.Connections[name]
end

local function RemoveConnection(name)
    if State.Connections[name] then
        pcall(function() State.Connections[name]:Disconnect() end)
        State.Connections[name] = nil
    end
end

local ActiveTimed = {}

local function RegisterTimedFeature(name, interval, callback)
    ActiveTimed[name] = { interval = interval, callback = callback, lastRun = 0 }
end

local function UnregisterTimedFeature(name)
    ActiveTimed[name] = nil
end

AddConnection("TimedTicker", RunService.Heartbeat, function()
    if State.Destroyed then return end
    local now = os.clock()
    for name, feat in pairs(ActiveTimed) do
        if now - feat.lastRun >= feat.interval then
            feat.lastRun = now
            local ok, err = pcall(feat.callback)
            if not ok then
                if not feat.lastErrLog or now - feat.lastErrLog > 5 then
                    feat.lastErrLog = now
                    LogErr(name, err)
                end
            end
        end
    end
end)

local function DisconnectAll()
    for _, c in pairs(State.Connections) do pcall(function() c:Disconnect() end) end
    State.Connections = {}
    ActiveTimed = {}
end

local function Create(class, props)
    local ok, obj = pcall(Instance.new, class)
    if not ok or not obj then return nil end
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    return obj
end

local function Tween(obj, time, props)
    if not obj or not obj.Parent then return end
    local ok, t = pcall(function()
        return TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and t then t:Play() return t end
end

local function GetChar() return LocalPlayer.Character end
local function GetHRP()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetCommF()
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    return r and r:FindFirstChild("CommF_")
end
local function GetEnemies()
    return Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("enemies")
end
local function GetChests()
    return Workspace:FindFirstChild("Chests") or Workspace:FindFirstChild("chests")
end

-- WEAPON
local WeaponPatterns = {
    Melee = {"combat", "black leg", "electro", "fishman", "superhuman", "death step", "sharkman", "electric claw", "dragon talon", "dragons breath", "dark step", "melee"},
    Sword = {"sword", "blade", "katana", "cutlass", "saber", "scythe", "trident", "spear", "yoru", "bisento", "pole", "cane"},
    Gun = {"gun", "pistol", "rifle", "bazooka", "slingshot", "cannon", "bow", "flintlock", "musket", "kabucha"}
}

local function IsToolMatching(tool, weaponType)
    if not tool then return false end
    local combined = (tool.Name or ""):lower() .. " " .. ((tool.ToolTip or "")):lower()
    local patterns = WeaponPatterns[weaponType]
    if not patterns then return true end
    for _, pattern in ipairs(patterns) do
        if combined:find(pattern, 1, true) then return true end
    end
    return false
end

local function GetSelectedTool()
    local char = GetChar()
    if not char then return nil end

    if State.SelectedWeapon == "Melee" then
        local hum = GetHum()
        if hum then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function() hum:UnequipTools() end)
            end
        end
        return nil
    end

    local tool = char:FindFirstChildOfClass("Tool")
    if tool and IsToolMatching(tool, State.SelectedWeapon) then return tool end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, bTool in ipairs(backpack:GetChildren()) do
            if bTool:IsA("Tool") and IsToolMatching(bTool, State.SelectedWeapon) then
                local hum = GetHum()
                if hum then
                    pcall(function() hum:EquipTool(bTool) end)
                    task.wait(0)
                    return bTool
                end
            end
        end
    end
    return tool
end

-- FIX v8: Melee dengan multi-fallback (mouse1click → mouse1press/release → VIM)
local function MeleeClick()
    if HasMouse1Click then
        pcall(function() mouse1click() end)
        return true
    end
    if HasMouse1Press and HasMouse1Release then
        pcall(function()
            mouse1press()
            task.wait(0.03)
            mouse1release()
        end)
        return true
    end
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.03)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
        return true
    end
    return false
end

local function ActivateTool()
    if State.SelectedWeapon == "Melee" then
        local char = GetChar()
        local hasTool = char and char:FindFirstChildOfClass("Tool")
        if not hasTool then
            local ok = MeleeClick()
            if not ok and not State.MeleeWarnShown then
                State.MeleeWarnShown = true
                warn("[SGVA-BF] Melee attack: tidak ada mouse function yang tersedia di executor ini")
            end
            return
        end
    end
    local tool = GetSelectedTool()
    if tool then pcall(function() tool:Activate() end) end
end

-- SCREEN GUI
local ScreenGui = Create("ScreenGui", {
    Name = "SGVA_BLOX_FRUITS",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 100
})
if not ScreenGui then LogErr("Init", "ScreenGui fail") return end

local okp = pcall(function() ScreenGui.Parent = UIParent end)
if not okp or not ScreenGui.Parent then
    pcall(function() ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end)
end

local UIScale = Create("UIScale", { Scale = 1, Parent = ScreenGui })
local DESIGN_WIDTH = 640
local DESIGN_HEIGHT = 420

local function GetCurrentScale()
    local s = UIScale.Scale
    if not s or s <= 0 then return 1 end
    return s
end

local function UpdateUIScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local scaleX = (vp.X - 20) / DESIGN_WIDTH
    local scaleY = (vp.Y - 40) / DESIGN_HEIGHT
    local scale = math.min(scaleX, scaleY)
    scale = math.clamp(scale, 0.35, 1)
    UIScale.Scale = scale
    if State.ActiveDropdown then
        pcall(function() State.ActiveDropdown() end)
    end
end
UpdateUIScale()

local function BindViewport()
    RemoveConnection("Viewport")
    local cam = Workspace.CurrentCamera
    if cam then
        AddConnection("Viewport", cam:GetPropertyChangedSignal("ViewportSize"), UpdateUIScale)
    end
end
BindViewport()
AddConnection("CameraChanged", Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    BindViewport()
    UpdateUIScale()
end)

local ToggleButton = Create("TextButton", {
    Size = UDim2.fromOffset(52, 52),
    Position = UDim2.fromOffset(20, 150),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = ScreenGui
})
Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ToggleButton })
Create("UIStroke", { Color = Theme.AccentGlow, Thickness = 2, Parent = ToggleButton })
Create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Text = "BF", TextColor3 = Color3.fromRGB(255,255,255),
    Font = Enum.Font.GothamBold, TextSize = 20, ZIndex = 2, Parent = ToggleButton
})

local MainFrame = Create("Frame", {
    Name = "MainFrame",
    Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
    Position = UDim2.new(0.5, -DESIGN_WIDTH/2, 0.5, -DESIGN_HEIGHT/2),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0, Parent = ScreenGui
})
Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = MainFrame })
Create("UIStroke", { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.4, Parent = MainFrame })

local Header = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Theme.Header, BorderSizePixel = 0, Parent = MainFrame
})
Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = Header })
Create("Frame", {
    Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Theme.Header, BorderSizePixel = 0, Parent = Header
})
Create("TextLabel", {
    Size = UDim2.new(0, 250, 1, 0), Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1, Text = "SGVA BLOX FRUITS",
    TextColor3 = Theme.AccentGlow, Font = Enum.Font.GothamBold,
    TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header
})

local HeaderBtnContainer = Create("Frame", {
    Size = UDim2.new(0, 150, 1, 0),
    Position = UDim2.new(1, -190, 0, 0),
    BackgroundTransparency = 1, Parent = Header
})
Create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4), Parent = HeaderBtnContainer
})
Create("UIPadding", { PaddingRight = UDim.new(0, 6), Parent = HeaderBtnContainer })

local function CreateHeaderBtn(text, w, cb)
    local b = Create("TextButton", {
        Size = UDim2.fromOffset(w, 24),
        BackgroundColor3 = Theme.PanelAccent, BorderSizePixel = 0,
        Text = text, TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham, TextSize = 10, AutoButtonColor = false,
        Parent = HeaderBtnContainer
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = b })
    b.MouseButton1Click:Connect(function() if cb then cb() end end)
    return b
end

local function ShowCreditsPopup()
    if State.CreditsPopup and State.CreditsPopup.Parent then
        State.CreditsPopup:Destroy()
        State.CreditsPopup = nil
    end
    local popup = Create("Frame", {
        Size = UDim2.fromOffset(320, 250),
        Position = UDim2.new(0.5, -160, 0.5, -125),
        BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = 200,
        Parent = ScreenGui
    })
    if not popup then return end
    Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = popup })
    Create("UIStroke", { Color = Theme.AccentGlow, Thickness = 2, Parent = popup })
    State.CreditsPopup = popup

    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 12),
        BackgroundTransparency = 1, Text = "CREDITS",
        TextColor3 = Theme.AccentGlow, Font = Enum.Font.GothamBold,
        TextSize = 16, ZIndex = 201, Parent = popup
    })
    Create("Frame", {
        Size = UDim2.new(1, -40, 0, 1), Position = UDim2.new(0, 20, 0, 44),
        BackgroundColor3 = Theme.Divider, BorderSizePixel = 0, ZIndex = 201, Parent = popup
    })
    local lines = {"- Dev: Saya", "- Project: Obsryn Project", "- Staff: No one", "", "Thanks For Use This Script"}
    for i, line in ipairs(lines) do
        local isLast = (i == 5)
        Create("TextLabel", {
            Size = UDim2.new(1, -40, 0, 24),
            Position = UDim2.new(0, 20, 0, 56 + (i-1) * 26),
            BackgroundTransparency = 1, Text = line,
            TextColor3 = isLast and Theme.AccentGlow or Theme.Text,
            Font = isLast and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextSize = isLast and 13 or 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 201, Parent = popup
        })
    end
    local cb = Create("TextButton", {
        Size = UDim2.fromOffset(120, 30),
        Position = UDim2.new(0.5, -60, 1, -42),
        BackgroundColor3 = Theme.AccentDark, BorderSizePixel = 0,
        Text = "CLOSE", TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false,
        ZIndex = 201, Parent = popup
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = cb })
    cb.MouseButton1Click:Connect(function()
        if popup and popup.Parent then popup:Destroy() end
        State.CreditsPopup = nil
    end)
end

CreateHeaderBtn("Credits", 55, ShowCreditsPopup)
CreateHeaderBtn("Settings", 58, function()
    if _G.SGVA_SwitchTab then _G.SGVA_SwitchTab("Misc") end
end)

local CloseBtn = Create("TextButton", {
    Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -30, 0, 7),
    BackgroundColor3 = Theme.Red, BackgroundTransparency = 0.6,
    BorderSizePixel = 0, Text = "X", TextColor3 = Color3.fromRGB(255,255,255),
    Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false, Parent = Header
})
Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = CloseBtn })

local SearchBar = Create("Frame", {
    Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 44),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = MainFrame
})
Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SearchBar })
Create("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = SearchBar })
Create("TextLabel", {
    Size = UDim2.fromOffset(24, 26), Position = UDim2.fromOffset(6, 0),
    BackgroundTransparency = 1, Text = "?", TextColor3 = Theme.TextDim,
    Font = Enum.Font.GothamBold, TextSize = 12, Parent = SearchBar
})
local SearchBox = Create("TextBox", {
    Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(28, 0),
    BackgroundTransparency = 1, Text = "",
    PlaceholderText = "Search...", PlaceholderColor3 = Theme.TextDark,
    TextColor3 = Theme.Text, Font = Enum.Font.Gotham, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = SearchBar
})

local TabBar = Create("Frame", {
    Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 74),
    BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = MainFrame
})
Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = TabBar })
Create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = TabBar
})
Create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = TabBar })

local Tabs = {}
local TabContents = {}
local tabList = {"Farm", "Fruit", "Raid", "Sea", "Player", "Misc"}

local function SwitchTab(name)
    for tabName, tabBtn in pairs(Tabs) do
        if tabName == name then
            Tween(tabBtn, 0.15, { BackgroundColor3 = Theme.AccentDark })
            tabBtn.TextColor3 = Theme.AccentGlow
        else
            Tween(tabBtn, 0.15, { BackgroundColor3 = Theme.PanelAccent })
            tabBtn.TextColor3 = Theme.TextDim
        end
    end
    for cname, content in pairs(TabContents) do
        if content.container then
            content.container.Visible = (cname == name)
        end
    end
    State.ActiveTab = name
end
_G.SGVA_SwitchTab = SwitchTab

for _, name in ipairs(tabList) do
    local tb = Create("TextButton", {
        Size = UDim2.fromOffset(78, 22),
        BackgroundColor3 = Theme.PanelAccent, BorderSizePixel = 0,
        Text = name, TextColor3 = Theme.TextDim,
        Font = Enum.Font.GothamBold, TextSize = 10, AutoButtonColor = false, Parent = TabBar
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = tb })
    Tabs[name] = tb
    tb.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        SwitchTab(name)
    end)
end

local ContentArea = Create("Frame", {
    Size = UDim2.new(1, -20, 1, -110), Position = UDim2.new(0, 10, 0, 106),
    BackgroundTransparency = 1, Parent = MainFrame
})

local SearchRegistry = {}
local SectionRegistry = {}
local CurrentSection = setmetatable({}, {__mode = "k"})

local function RegisterSearch(frame, keyword, section)
    table.insert(SearchRegistry, {frame = frame, keyword = keyword:lower(), section = section})
    if section then
        if not SectionRegistry[section] then SectionRegistry[section] = {} end
        table.insert(SectionRegistry[section], frame)
    end
end

local function CreateTabContent(name)
    local container = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Visible = false, Parent = ContentArea
    })
    local leftPanel = Create("Frame", {
        Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0, Parent = container
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = leftPanel })
    Create("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = leftPanel })

    local rightPanel = Create("Frame", {
        Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0),
        BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = container
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = rightPanel })
    Create("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = rightPanel })

    local leftScroll = Create("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -12), Position = UDim2.new(0, 6, 0, 6),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), Parent = leftPanel
    })
    Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = leftScroll })

    local rightScroll = Create("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -12), Position = UDim2.new(0, 6, 0, 6),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), Parent = rightPanel
    })
    Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightScroll })

    for _, scroll in ipairs({leftScroll, rightScroll}) do
        local layout = scroll:FindFirstChildOfClass("UIListLayout")
        if layout then
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
            end)
        end
    end

    local content = { left = leftScroll, right = rightScroll, container = container }
    TabContents[name] = content
    return content
end

local function CreateSection(parent, title)
    local sec = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = Theme.PanelAccent, BorderSizePixel = 0, Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = sec })
    Create("Frame", {
        Size = UDim2.new(0, 3, 0.55, 0), Position = UDim2.new(0, 6, 0.22, 0),
        BackgroundColor3 = Theme.AccentGlow, BorderSizePixel = 0, Parent = sec
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1, Text = title,
        TextColor3 = Theme.AccentGlow, Font = Enum.Font.GothamBold,
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, Parent = sec
    })
    CurrentSection[parent] = sec
    return sec
end

local function CreateToggle(parent, text, default, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.PanelLight, BorderSizePixel = 0, Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = frame })
    Create("TextLabel", {
        Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Text = text, TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = frame
    })
    local btn = Create("TextButton", {
        Size = UDim2.fromOffset(34, 16), Position = UDim2.new(1, -42, 0.5, -8),
        BackgroundColor3 = default and Theme.ToggleOn or Theme.ToggleOff,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = frame
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = btn })
    local knob = Create("Frame", {
        Size = UDim2.fromOffset(12, 12),
        Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0, Parent = btn
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

    local isOn = default
    btn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        isOn = not isOn
        Tween(btn, 0.15, { BackgroundColor3 = isOn and Theme.ToggleOn or Theme.ToggleOff })
        Tween(knob, 0.15, { Position = isOn and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) })
        if callback then
            local ok, err = pcall(callback, isOn)
            if not ok then LogErr("Toggle:" .. text, err) end
        end
    end)
    RegisterSearch(frame, text, CurrentSection[parent])
    return frame
end

local function CreateSlider(parent, text, min, max, default, suffix, callback)
    local label = text .. (suffix and (" (" .. suffix .. ")") or "")
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.PanelLight, BorderSizePixel = 0, Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = frame })
    Create("TextLabel", {
        Size = UDim2.new(0.6, 0, 0, 16), Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1, Text = label, TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = frame
    })
    local vb = Create("TextLabel", {
        Size = UDim2.fromOffset(50, 16), Position = UDim2.new(1, -60, 0, 4),
        BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
        Text = tostring(default), TextColor3 = Theme.AccentGlow,
        Font = Enum.Font.GothamBold, TextSize = 10, Parent = frame
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = vb })
    local barBg = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 5), Position = UDim2.new(0, 10, 0, 26),
        BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = frame
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBg })
    local barFill = Create("Frame", {
        Size = UDim2.new((default-min)/(max-min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = barBg
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barFill })

    local value = default
    local dragging = false
    local function update(input)
        if State.Destroyed then return end
        local mx = input.Position.X
        local bp = barBg.AbsolutePosition.X
        local bs = barBg.AbsoluteSize.X
        if bs <= 0 then return end
        local rel = math.clamp((mx - bp) / bs, 0, 1)
        value = math.floor(min + (max - min) * rel)
        barFill.Size = UDim2.new(rel, 0, 1, 0)
        vb.Text = tostring(value)
        if callback then
            local ok, err = pcall(callback, value)
            if not ok then LogErr("Slider:" .. text, err) end
        end
    end
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    local sid = "S_" .. tostring(math.random(1, 9999999))
    AddConnection(sid .. "_c", UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    AddConnection(sid .. "_e", UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    RegisterSearch(frame, text, CurrentSection[parent])
    return frame
end

local function CreateButton(parent, text, callback)
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.AccentDark, BorderSizePixel = 0,
        Text = text, TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = btn })
    Create("UIStroke", { Color = Theme.Accent, Thickness = 1, Transparency = 0.5, Parent = btn })
    btn.MouseEnter:Connect(function() Tween(btn, 0.1, { BackgroundColor3 = Theme.Accent }) end)
    btn.MouseLeave:Connect(function() Tween(btn, 0.1, { BackgroundColor3 = Theme.AccentDark }) end)
    btn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        if callback then
            local ok, err = pcall(callback)
            if not ok then LogErr("Button:" .. text, err) end
        end
    end)
    RegisterSearch(btn, text, CurrentSection[parent])
    return btn
end

local function CreateDropdown(parent, text, options, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.PanelLight, BorderSizePixel = 0, Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = frame })
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = text .. ": " .. options[1], TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Parent = frame
    })
    Create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = btn })
    if callback then pcall(callback, options[1]) end

    local isOpen = false
    local optFrame = nil
    local backdrop = nil

    local function closeDropdown()
        if optFrame and optFrame.Parent then optFrame:Destroy() end
        if backdrop and backdrop.Parent then backdrop:Destroy() end
        optFrame = nil
        backdrop = nil
        isOpen = false
        if State.ActiveDropdown == closeDropdown then
            State.ActiveDropdown = nil
        end
    end

    local function buildDropdown()
        if optFrame and optFrame.Parent then optFrame:Destroy() end
        if backdrop and backdrop.Parent then backdrop:Destroy() end

        local scale = GetCurrentScale()
        local absPos = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize

        backdrop = Create("TextButton", {
            Size = UDim2.fromOffset(100000 / scale, 100000 / scale),
            Position = UDim2.fromOffset(-50000 / scale, -50000 / scale),
            BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 4999, Parent = ScreenGui
        })
        backdrop.MouseButton1Click:Connect(function() closeDropdown() end)

        optFrame = Create("Frame", {
            Size = UDim2.fromOffset(absSize.X / scale, #options * 22),
            Position = UDim2.fromOffset(absPos.X / scale, (absPos.Y + absSize.Y + 2) / scale),
            BackgroundColor3 = Theme.PanelAccent, BorderSizePixel = 0,
            ZIndex = 5000, Parent = ScreenGui
        })
        Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = optFrame })
        Create("UIStroke", { Color = Theme.Accent, Thickness = 1, Parent = optFrame })

        for i, opt in ipairs(options) do
            local ob = Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 22),
                Position = UDim2.new(0, 0, 0, (i-1) * 22),
                BackgroundTransparency = 1, Text = opt,
                TextColor3 = Theme.Text, Font = Enum.Font.Gotham,
                TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 5001, AutoButtonColor = false, Parent = optFrame
            })
            Create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = ob })
            ob.MouseButton1Click:Connect(function()
                btn.Text = text .. ": " .. opt
                if callback then
                    local ok, err = pcall(callback, opt)
                    if not ok then LogErr("Dropdown:" .. text, err) end
                end
                closeDropdown()
            end)
        end
    end

    btn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        if isOpen then
            closeDropdown()
            return
        end
        if State.ActiveDropdown and State.ActiveDropdown ~= closeDropdown then
            pcall(State.ActiveDropdown)
        end
        isOpen = true
        State.ActiveDropdown = closeDropdown
        buildDropdown()
    end)

    RegisterSearch(frame, text, CurrentSection[parent])
    return frame
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = SearchBox.Text:lower()
    State.SearchText = query
    for _, entry in ipairs(SearchRegistry) do
        if entry.frame and entry.frame.Parent then
            if query == "" then
                entry.frame.Visible = true
            else
                entry.frame.Visible = entry.keyword:find(query, 1, true) ~= nil
            end
        end
    end
    for section, frames in pairs(SectionRegistry) do
        if section and section.Parent then
            if query == "" then
                section.Visible = true
            else
                local anyVisible = false
                for _, f in ipairs(frames) do
                    if f and f.Parent and f.Visible then anyVisible = true break end
                end
                section.Visible = anyVisible
            end
        end
    end
end)

local FarmTab = CreateTabContent("Farm")
CreateSection(FarmTab.left, "FARM TOGGLES")
CreateToggle(FarmTab.left, "Auto Farm", false, function(v) State.AutoFarm = v; ToggleAutoFarm(v) end)
CreateToggle(FarmTab.left, "Auto Chest", false, function(v) State.AutoChest = v; ToggleAutoChest(v) end)
CreateToggle(FarmTab.left, "Auto Bone", false, function(v) State.AutoBone = v; ToggleAutoBone(v) end)
CreateToggle(FarmTab.left, "Auto Mastery", false, function(v) State.AutoMastery = v; ToggleAutoMastery(v) end)
CreateToggle(FarmTab.left, "Auto Quest", false, function(v) State.AutoQuest = v; ToggleAutoQuest(v) end)
CreateToggle(FarmTab.left, "Kill Aura", false, function(v) State.KillAura = v; ToggleKillAura(v) end)
CreateToggle(FarmTab.left, "Bring Mob", false, function(v) State.BringMob = v; ToggleBringMob(v) end)

CreateSection(FarmTab.right, "FARM SETTINGS")
CreateDropdown(FarmTab.right, "Farm Mode", {"Nearest", "All", "Boss"}, function(v) State.AutoFarmMode = v end)
CreateDropdown(FarmTab.right, "Weapon", {"Melee", "Sword", "Gun"}, function(v) State.SelectedWeapon = v end)
CreateSlider(FarmTab.right, "Attack Delay", 5, 100, 15, "x10ms", function(v) State.AttackDelay = v / 100 end)
CreateSlider(FarmTab.right, "Search Radius", 50, 1000, 300, "studs", function(v) State.SearchRadius = v end)
CreateSlider(FarmTab.right, "Farm Offset", 5, 50, 18, "studs", function(v) State.FarmOffset = v end)
CreateSlider(FarmTab.right, "Tween Speed", 50, 1000, 250, "studs/s", function(v) State.TweenSpeed = v end)
CreateSlider(FarmTab.right, "Bring Radius", 50, 1000, 350, "studs", function(v) State.BringRadius = v end)

local FruitTab = CreateTabContent("Fruit")
CreateSection(FruitTab.left, "FRUIT TOGGLES")
CreateToggle(FruitTab.left, "Fruit Sniper", false, function(v) State.FruitSniper = v; ToggleFruitSniper(v) end)
CreateToggle(FruitTab.left, "Auto Store Fruit", false, function(v) State.AutoStoreFruit = v; ToggleAutoStoreFruit(v) end)
CreateToggle(FruitTab.left, "ESP Fruit", false, function(v) State.ESPFruit = v; ToggleESPFruit(v) end)

CreateSection(FruitTab.right, "FRUIT SETTINGS")
CreateDropdown(FruitTab.right, "Select Fruit", {"Rocket", "Spin", "Blade", "Spring", "Bomb", "Smoke", "Spike", "Flame", "Falcon", "Ice", "Sand", "Dark", "Diamond", "Light", "Rubber", "Barrier", "Ghost", "Magma", "Quake", "Buddha", "Love", "Spider", "Sound", "Phoenix", "Portal", "Rumble", "Pain", "Blizzard", "Gravity", "Mammoth", "T-Rex", "Dough", "Shadow", "Venom", "Control", "Spirit", "Dragon", "Leopard", "Kitsune"}, function(v) State.SelectedFruit = v end)
CreateButton(FruitTab.right, "Teleport to Selected Fruit", function() TeleportToFruit(State.SelectedFruit) end)

local RaidTab = CreateTabContent("Raid")
CreateSection(RaidTab.left, "RAID TOGGLES")
CreateToggle(RaidTab.left, "Auto Raid", false, function(v) State.AutoRaid = v; ToggleAutoRaid(v) end)
CreateToggle(RaidTab.left, "Kill All Raid NPCs", false, function(v) State.KillAllRaid = v; ToggleKillAllRaid(v) end)
CreateToggle(RaidTab.left, "Auto Next Island", false, function(v) State.AutoNextIsland = v; ToggleAutoNextIsland(v) end)

CreateSection(RaidTab.right, "RAID SETTINGS")
CreateDropdown(RaidTab.right, "Raid Chip", {"Flame", "Ice", "Quake", "Light", "Dark", "Spider", "Rumble", "Magma", "Buddha", "Love", "Creation", "Spirit", "Portal", "Blizzard", "Pain", "Dough", "Shadow", "Venom", "Control", "Gravity"}, function(v) State.RaidChip = v end)
CreateSlider(RaidTab.right, "Raid Min HP", 500, 5000, 1000, "HP", function(v) State.RaidMinHealth = v end)
CreateButton(RaidTab.right, "Buy Raid Chip", function() BuyRaidChip(State.RaidChip) end)
CreateButton(RaidTab.right, "Start Raid", function() StartRaid() end)
CreateButton(RaidTab.right, "Teleport to Raid Island", function() TeleportRaidIsland() end)

local SeaTab = CreateTabContent("Sea")
CreateSection(SeaTab.left, "SEA TOGGLES")
CreateToggle(SeaTab.left, "Auto Fish", false, function(v) State.AutoFish = v; ToggleAutoFish(v) end)
CreateToggle(SeaTab.left, "Sea Beast Farm", false, function(v) State.SeaBeastFarm = v; ToggleSeaBeastFarm(v) end)

CreateSection(SeaTab.right, "SEA INFO")
CreateButton(SeaTab.right, "Teleport to Sea Beast", function() TeleportSeaBeast() end)
CreateButton(SeaTab.right, "Spawn Boat", function() SpawnBoat() end)

local PlayerTab = CreateTabContent("Player")
CreateSection(PlayerTab.left, "PLAYER TOGGLES")
CreateToggle(PlayerTab.left, "ESP Player", false, function(v) State.ESPPlayer = v; ToggleESPPlayer(v) end)
CreateToggle(PlayerTab.left, "ESP Enemy", false, function(v) State.ESPEnemy = v; ToggleESPEnemy(v) end)
CreateToggle(PlayerTab.left, "Noclip", false, function(v) State.Noclip = v; ToggleNoclip(v) end)
CreateToggle(PlayerTab.left, "Fly", false, function(v) State.Fly = v; ToggleFly(v) end)
CreateToggle(PlayerTab.left, "Fast Walk", false, function(v) State.FastWalk = v; ToggleFastWalk(v) end)
CreateToggle(PlayerTab.left, "Moon Jump", false, function(v) State.MoonJump = v; ToggleMoonJump(v) end)

CreateSection(PlayerTab.right, "PLAYER SETTINGS")
CreateSlider(PlayerTab.right, "Fly Speed", 10, 300, 80, "studs/s", function(v) State.FlySpeed = v end)
CreateSlider(PlayerTab.right, "Walk Speed", 16, 300, 50, "studs/s", function(v) State.WalkSpeed = v end)
CreateSlider(PlayerTab.right, "Jump Power", 50, 500, 150, "studs", function(v) State.JumpPower = v end)

local MiscTab = CreateTabContent("Misc")
CreateSection(MiscTab.left, "MISC TOGGLES")
CreateToggle(MiscTab.left, "Anti AFK", true, function(v) State.AntiAFK = v; ToggleAntiAFK(v) end)
CreateToggle(MiscTab.left, "FPS Boost", false, function(v) State.FPSBoost = v; ToggleFPSBoost(v) end)

CreateSection(MiscTab.right, "SERVER & ACTIONS")
CreateButton(MiscTab.right, "Server Hop", function() ServerHop() end)
CreateButton(MiscTab.right, "Rejoin Server", function()
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end)
CreateButton(MiscTab.right, "Reset Character", function()
    local c = GetChar()
    if c then c:BreakJoints() end
end)
CreateButton(MiscTab.right, "Unload Script", function() Cleanup() end)

SwitchTab("Farm")

-- FEATURES
function ToggleAntiAFK(state)
    if state then
        AddConnection("AntiAFK", LocalPlayer.Idled, function()
            if not State.AntiAFK then return end
            if VirtualUser then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end)
    else
        RemoveConnection("AntiAFK")
    end
end

local NoclipParts = {}
local NoclipOriginal = {}

local function RefreshNoclipCache()
    table.clear(NoclipParts)
    table.clear(NoclipOriginal)
    local char = GetChar()
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            table.insert(NoclipParts, v)
            NoclipOriginal[v] = v.CanCollide
        end
    end
end

function ToggleNoclip(state)
    if state then
        RefreshNoclipCache()
        RegisterTimedFeature("Noclip", 0.1, function()
            if not State.Noclip then return end
            for _, part in ipairs(NoclipParts) do
                if part and part.Parent and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        UnregisterTimedFeature("Noclip")
        for obj, val in pairs(NoclipOriginal) do
            if obj and obj.Parent then pcall(function() obj.CanCollide = val end) end
        end
        table.clear(NoclipParts)
        table.clear(NoclipOriginal)
    end
end

local function SetupFly(hrp)
    if not hrp then return end
    for _, name in ipairs({"SGVA_FlyAttach", "SGVA_FlyLV", "SGVA_OrientAttach", "SGVA_FlyAO"}) do
        local old = hrp:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local flyAttach = Instance.new("Attachment")
    flyAttach.Name = "SGVA_FlyAttach"
    flyAttach.Parent = hrp
    local lv = Instance.new("LinearVelocity")
    lv.Name = "SGVA_FlyLV"
    lv.Attachment0 = flyAttach
    lv.MaxForce = math.huge
    lv.VectorVelocity = Vector3.zero
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.Parent = hrp
    local orientAttach = Instance.new("Attachment")
    orientAttach.Name = "SGVA_OrientAttach"
    orientAttach.Parent = hrp
    local ao = Instance.new("AlignOrientation")
    ao.Name = "SGVA_FlyAO"
    ao.Attachment0 = orientAttach
    ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
    ao.MaxTorque = math.huge
    ao.Responsiveness = 100
    ao.Parent = hrp
end

function ToggleFly(state)
    if state then
        local hrp = GetHRP()
        if hrp then SetupFly(hrp) end
        RegisterTimedFeature("Fly", 0, function()
            if not State.Fly then return end
            local char = GetChar()
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            local camera = Workspace.CurrentCamera
            if not hum or not root or not camera then return end
            local lv = root:FindFirstChild("SGVA_FlyLV")
            local ao = root:FindFirstChild("SGVA_FlyAO")
            if not lv or not ao then
                SetupFly(root)
                lv = root:FindFirstChild("SGVA_FlyLV")
                ao = root:FindFirstChild("SGVA_FlyAO")
            end
            if not lv or not ao then return end
            hum.AutoRotate = false
            local camCF = camera.CFrame
            local lookVec = camCF.LookVector
            local rightVec = camCF.RightVector
            local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z)
            local flatRight = Vector3.new(rightVec.X, 0, rightVec.Z)
            if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit
            else flatLook = Vector3.new(0, 0, -1) end
            if flatRight.Magnitude > 0.001 then flatRight = flatRight.Unit
            else flatRight = Vector3.new(1, 0, 0) end
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += lookVec end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= lookVec end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move -= Vector3.new(0,1,0) end
            local md = hum.MoveDirection
            if md.Magnitude > 0.05 then
                local fwdAmt = md:Dot(flatLook)
                local strAmt = md:Dot(flatRight)
                move += lookVec * fwdAmt
                move += flatRight * strAmt
            end
            if move.Magnitude > 0.001 then
                lv.VectorVelocity = move.Unit * State.FlySpeed
            else
                lv.VectorVelocity = Vector3.zero
            end
            local facing = Vector3.new(lookVec.X, 0, lookVec.Z)
            if facing.Magnitude > 0.001 then
                ao.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
            end
        end)
    else
        UnregisterTimedFeature("Fly")
        local root = GetHRP()
        if root then
            for _, name in ipairs({"SGVA_FlyAttach", "SGVA_FlyLV", "SGVA_OrientAttach", "SGVA_FlyAO"}) do
                local obj = root:FindFirstChild(name)
                if obj then obj:Destroy() end
            end
        end
        local hum = GetHum()
        if hum then hum.AutoRotate = true end
    end
end

function ToggleFastWalk(state)
    if state then
        RegisterTimedFeature("FastWalk", 0.1, function()
            if not State.FastWalk then return end
            local hum = GetHum()
            if hum then hum.WalkSpeed = State.WalkSpeed end
        end)
    else
        UnregisterTimedFeature("FastWalk")
        local hum = GetHum()
        if hum then hum.WalkSpeed = State.BaseWalkSpeed end
    end
end

function ToggleMoonJump(state)
    if state then
        RegisterTimedFeature("MoonJump", 0.1, function()
            if not State.MoonJump then return end
            local hum = GetHum()
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = State.JumpPower
            end
        end)
    else
        UnregisterTimedFeature("MoonJump")
        local hum = GetHum()
        if hum then hum.JumpPower = State.BaseJumpPower end
    end
end

local ActiveTween = nil
local LastTweenTarget = nil
local LastTweenRestart = 0

local function TweenTo(targetPos, isMovingTarget)
    local hrp = GetHRP()
    if not hrp then return end
    local now = os.clock()
    if ActiveTween and isMovingTarget and (now - LastTweenRestart) < 0.4 then
        return
    end
    if ActiveTween and LastTweenTarget then
        if (LastTweenTarget - targetPos).Magnitude < 3 then
            return
        end
    end
    if ActiveTween then
        pcall(function() ActiveTween:Cancel() end)
        ActiveTween = nil
    end
    local dist = (hrp.Position - targetPos).Magnitude
    if dist < 2 then return end
    local speed = math.max(50, State.TweenSpeed)
    local duration = math.clamp(dist / speed, 0.05, 5)
    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    tween:Play()
    ActiveTween = tween
    LastTweenTarget = targetPos
    LastTweenRestart = now
    tween.Completed:Connect(function()
        if ActiveTween == tween then
            ActiveTween = nil
            LastTweenTarget = nil
        end
    end)
end

function ToggleAutoFarm(state)
    if state then
        RegisterTimedFeature("AutoFarm", 0.1, function()
            if not State.AutoFarm then return end
            local hrp = GetHRP()
            if not hrp then return end
            local enemies = GetEnemies()
            if not enemies then return end
            local function isBoss(mob, mh)
                return mob.Name:lower():find("boss") ~= nil or mh.MaxHealth >= 5000
            end
            if State.AutoFarmMode == "Nearest" then
                local closest, shortest = nil, State.SearchRadius
                for _, mob in ipairs(enemies:GetChildren()) do
                    local mh = mob:FindFirstChildOfClass("Humanoid")
                    local mhrp = mob:FindFirstChild("HumanoidRootPart")
                    if mh and mhrp and mh.Health > 0 then
                        local d = (mhrp.Position - hrp.Position).Magnitude
                        if d <= State.SearchRadius and d < shortest then
                            shortest = d
                            closest = mob
                        end
                    end
                end
                if closest and closest:FindFirstChild("HumanoidRootPart") then
                    TweenTo(closest.HumanoidRootPart.Position + Vector3.new(0, State.FarmOffset, 0), true)
                    ActivateTool()
                end
            elseif State.AutoFarmMode == "All" then
                local locked = State.ActiveFarmTarget
                local lockedValid = false
                if locked and locked.Parent then
                    local mh = locked:FindFirstChildOfClass("Humanoid")
                    local mhrp = locked:FindFirstChild("HumanoidRootPart")
                    if mh and mhrp and mh.Health > 0 then
                        lockedValid = true
                        TweenTo(mhrp.Position + Vector3.new(0, State.FarmOffset, 0), true)
                        ActivateTool()
                    end
                end
                if not lockedValid then
                    State.ActiveFarmTarget = nil
                    local targets = {}
                    for _, mob in ipairs(enemies:GetChildren()) do
                        local mh = mob:FindFirstChildOfClass("Humanoid")
                        local mhrp = mob:FindFirstChild("HumanoidRootPart")
                        if mh and mhrp and mh.Health > 0 then
                            local d = (mhrp.Position - hrp.Position).Magnitude
                            if d <= State.SearchRadius then
                                table.insert(targets, {mob = mob, dist = d})
                            end
                        end
                    end
                    table.sort(targets, function(a, b) return a.dist < b.dist end)
                    if #targets > 0 then
                        local t = targets[1]
                        State.ActiveFarmTarget = t.mob
                        local mhrp = t.mob:FindFirstChild("HumanoidRootPart")
                        if mhrp then
                            TweenTo(mhrp.Position + Vector3.new(0, State.FarmOffset, 0), true)
                            ActivateTool()
                        end
                    end
                end
            elseif State.AutoFarmMode == "Boss" then
                local closest, shortest = nil, State.SearchRadius
                for _, mob in ipairs(enemies:GetChildren()) do
                    local mh = mob:FindFirstChildOfClass("Humanoid")
                    local mhrp = mob:FindFirstChild("HumanoidRootPart")
                    if mh and mhrp and mh.Health > 0 and isBoss(mob, mh) then
                        local d = (mhrp.Position - hrp.Position).Magnitude
                        if d <= State.SearchRadius and d < shortest then
                            shortest = d
                            closest = mob
                        end
                    end
                end
                if closest and closest:FindFirstChild("HumanoidRootPart") then
                    TweenTo(closest.HumanoidRootPart.Position + Vector3.new(0, State.FarmOffset, 0), true)
                    ActivateTool()
                end
            end
        end)
    else
        UnregisterTimedFeature("AutoFarm")
        State.ActiveFarmTarget = nil
        if ActiveTween then
            pcall(function() ActiveTween:Cancel() end)
            ActiveTween = nil
        end
        LastTweenTarget = nil
    end
end

function ToggleAutoChest(state)
    if state then
        RegisterTimedFeature("AutoChest", 0.3, function()
            if not State.AutoChest then return end
            local hrp = GetHRP()
            if not hrp then return end
            local chests = GetChests()
            if not chests then return end
            local closest, shortest = nil, 500
            for _, chest in ipairs(chests:GetChildren()) do
                if chest:IsA("BasePart") or chest:IsA("Model") then
                    local part = chest:IsA("BasePart") and chest or chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local d = (part.Position - hrp.Position).Magnitude
                        if d < shortest then
                            shortest = d
                            closest = part
                        end
                    end
                end
            end
            if closest then
                hrp.CFrame = CFrame.new(closest.Position + Vector3.new(0, 3, 0))
            end
        end)
    else
        UnregisterTimedFeature("AutoChest")
    end
end

function ToggleAutoBone(state)
    if state then
        RegisterTimedFeature("AutoBone", 0.3, function()
            if not State.AutoBone then return end
            local hrp = GetHRP()
            if not hrp then return end
            local boneFolder = Workspace:FindFirstChild("Bones") or Workspace:FindFirstChild("SpawnedBones")
            local function tryScan(container)
                if not container then return false end
                for _, obj in ipairs(container:GetChildren()) do
                    if obj:IsA("BasePart") then
                        local d = (obj.Position - hrp.Position).Magnitude
                        if d < 500 then
                            hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                            return true
                        end
                    end
                end
                return false
            end
            if tryScan(boneFolder) then return end
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("BasePart") and obj.Name:lower():find("bone") then
                    local d = (obj.Position - hrp.Position).Magnitude
                    if d < 500 then
                        hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                        return
                    end
                end
            end
        end)
    else
        UnregisterTimedFeature("AutoBone")
    end
end

function ToggleAutoMastery(state)
    if state then
        RegisterTimedFeature("AutoMastery", 0.05, function()
            if not State.AutoMastery then return end
            local now = os.clock()
            local feat = ActiveTimed["AutoMastery"]
            if not feat then return end
            if now - (feat.lastAttack or 0) < State.AttackDelay then return end
            feat.lastAttack = now
            ActivateTool()
        end)
    else
        UnregisterTimedFeature("AutoMastery")
    end
end

-- FIX v8: AutoQuest dengan cycle + enemy alive check
function ToggleAutoQuest(state)
    if state then
        State.QuestState = "idle"
        State.QuestLastCheck = 0
        RegisterTimedFeature("AutoQuest", 1, function()
            if not State.AutoQuest then return end
            local commF = GetCommF()
            if not commF then return end
            local now = os.clock()

            if State.QuestState == "idle" then
                -- Cek apakah ada enemy hidup di sekitar
                local hrp = GetHRP()
                local enemies = GetEnemies()
                local liveNearby = 0
                if hrp and enemies then
                    for _, mob in ipairs(enemies:GetChildren()) do
                        local mh = mob:FindFirstChildOfClass("Humanoid")
                        local mhrp = mob:FindFirstChild("HumanoidRootPart")
                        if mh and mhrp and mh.Health > 0 then
                            local d = (mhrp.Position - hrp.Position).Magnitude
                            if d < 100 then liveNearby = liveNearby + 1 end
                        end
                    end
                end

                -- Kalau tidak ada enemy dekat (quest mungkin selesai), request quest baru
                if liveNearby == 0 then
                    pcall(function()
                        commF:InvokeServer("StartQuest")
                    end)
                    State.QuestState = "cooldown"
                    State.QuestLastCheck = now
                end

            elseif State.QuestState == "cooldown" then
                -- Tunggu 5 detik sebelum cek lagi
                if now - State.QuestLastCheck >= 5 then
                    State.QuestState = "idle"
                    State.QuestLastCheck = now
                end
            end
        end)
    else
        UnregisterTimedFeature("AutoQuest")
        State.QuestState = "idle"
    end
end

function ToggleKillAura(state)
    if state then
        RegisterTimedFeature("KillAura", 0.05, function()
            if not State.KillAura then return end
            local now = os.clock()
            local feat = ActiveTimed["KillAura"]
            if not feat then return end
            if now - (feat.lastAttack or 0) < State.AttackDelay then return end
            feat.lastAttack = now
            ActivateTool()
        end)
    else
        UnregisterTimedFeature("KillAura")
    end
end

function ToggleBringMob(state)
    if state then
        RegisterTimedFeature("BringMob", 0.2, function()
            if not State.BringMob then return end
            local hrp = GetHRP()
            if not hrp then return end
            local enemies = GetEnemies()
            if not enemies then return end
            for _, mob in ipairs(enemies:GetChildren()) do
                local mh = mob:FindFirstChildOfClass("Humanoid")
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if mh and mhrp and mh.Health > 0 then
                    local d = (mhrp.Position - hrp.Position).Magnitude
                    if d < State.BringRadius and d > 3 then
                        mhrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
                    end
                end
            end
        end)
    else
        UnregisterTimedFeature("BringMob")
    end
end

local ESPNames = { Player = "SGVA_ESP_Player", Enemy = "SGVA_ESP_Enemy", Fruit = "SGVA_ESP_Fruit" }

local function CreateESP(part, color, name)
    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.6
    hl.Name = name
    hl.Parent = part
    return hl
end

local function ClearESPByName(name)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == name then pcall(function() v:Destroy() end) end
    end
end

function ToggleESPEnemy(state)
    if state then
        RegisterTimedFeature("ESPEnemy", 0.5, function()
            if not State.ESPEnemy then return end
            local enemies = GetEnemies()
            if not enemies then return end
            for _, mob in ipairs(enemies:GetChildren()) do
                local hrp = mob:FindFirstChild("HumanoidRootPart")
                if hrp and not hrp:FindFirstChild(ESPNames.Enemy) then
                    CreateESP(hrp, Color3.fromRGB(255, 60, 90), ESPNames.Enemy)
                end
            end
        end)
    else
        UnregisterTimedFeature("ESPEnemy")
        ClearESPByName(ESPNames.Enemy)
    end
end

function ToggleESPPlayer(state)
    if state then
        RegisterTimedFeature("ESPPlayer", 0.5, function()
            if not State.ESPPlayer then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and not hrp:FindFirstChild(ESPNames.Player) then
                        CreateESP(hrp, Color3.fromRGB(0, 220, 130), ESPNames.Player)
                    end
                end
            end
        end)
    else
        UnregisterTimedFeature("ESPPlayer")
        ClearESPByName(ESPNames.Player)
    end
end

function ToggleESPFruit(state)
    if state then
        RegisterTimedFeature("ESPFruit", 0.5, function()
            if not State.ESPFruit then return end
            for _, v in ipairs(Workspace:GetChildren()) do
                if v:IsA("Tool") and v:FindFirstChild("Handle") then
                    if not v.Handle:FindFirstChild(ESPNames.Fruit) then
                        CreateESP(v.Handle, Color3.fromRGB(255, 200, 0), ESPNames.Fruit)
                    end
                end
            end
        end)
    else
        UnregisterTimedFeature("ESPFruit")
        ClearESPByName(ESPNames.Fruit)
    end
end

function ToggleFruitSniper(state)
    if state then
        RegisterTimedFeature("FruitSniper", 0.5, function()
            if not State.FruitSniper then return end
            local hrp = GetHRP()
            if not hrp then return end
            local wanted = State.SelectedFruit
            if wanted == "None" or wanted == "" then return end
            for _, v in ipairs(Workspace:GetChildren()) do
                if v:IsA("Tool") and v.Name:lower():find(wanted:lower(), 1, true) and v:FindFirstChild("Handle") then
                    hrp.CFrame = CFrame.new(v.Handle.Position + Vector3.new(0, 3, 0))
                    return
                end
            end
        end)
    else
        UnregisterTimedFeature("FruitSniper")
    end
end

function ToggleAutoStoreFruit(state)
    if state then
        RegisterTimedFeature("AutoStoreFruit", 3, function()
            if not State.AutoStoreFruit then return end
            local commF = GetCommF()
            if not commF then return end
            local ok, err = pcall(function() commF:InvokeServer("StoreFruit") end)
            if not ok then LogErr("AutoStoreFruit", err) end
        end)
    else
        UnregisterTimedFeature("AutoStoreFruit")
    end
end

function TeleportToFruit(name)
    local hrp = GetHRP()
    if not hrp then return end
    if name == "None" or name == "" then return end
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:IsA("Tool") and v.Name:lower():find(name:lower()) and v:FindFirstChild("Handle") then
            hrp.CFrame = CFrame.new(v.Handle.Position + Vector3.new(0, 3, 0))
            return
        end
    end
end

function BuyRaidChip(fruit)
    local commF = GetCommF()
    if not commF then return end
    local ok, err = pcall(function() commF:InvokeServer("Raids", 1, fruit) end)
    if not ok then LogErr("BuyRaidChip", err) end
end

function StartRaid()
    local commF = GetCommF()
    if not commF then return end
    local ok, err = pcall(function() commF:InvokeServer("Raids", 2) end)
    if not ok then LogErr("StartRaid", err) end
end

function TeleportRaidIsland()
    local commF = GetCommF()
    if not commF then return end
    pcall(function() commF:InvokeServer("requestEntrance", "CursedShip") end)
end

local function SnapshotEnemies()
    local snapshot = {}
    local enemies = GetEnemies()
    if not enemies then return snapshot end
    for _, mob in ipairs(enemies:GetChildren()) do
        snapshot[mob] = true
    end
    return snapshot
end

-- FIX v8: filter HP + radius
local function CountNewLiveEnemiesNearby(snapshot, radius, minHealth)
    local count = 0
    local enemies = GetEnemies()
    if not enemies then return 0 end
    local hrp = GetHRP()
    if not hrp then return 0 end
    for _, mob in ipairs(enemies:GetChildren()) do
        if not snapshot[mob] then
            local mh = mob:FindFirstChildOfClass("Humanoid")
            local mhrp = mob:FindFirstChild("HumanoidRootPart")
            if mh and mhrp and mh.Health > 0 then
                local d = (mhrp.Position - hrp.Position).Magnitude
                if d <= radius and mh.MaxHealth >= minHealth then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function ToggleAutoRaid(state)
    if state then
        State.RaidState = "checking"
        State.RaidSnapshot = nil
        State.RaidLastCheck = 0
        RegisterTimedFeature("AutoRaid", 1, function()
            if not State.AutoRaid then return end
            local now = os.clock()

            if State.RaidState == "checking" then
                State.RaidSnapshot = SnapshotEnemies()
                StartRaid()
                State.RaidState = "starting"
                State.RaidLastCheck = now

            elseif State.RaidState == "starting" then
                local newEnemies = CountNewLiveEnemiesNearby(State.RaidSnapshot or {}, 150, State.RaidMinHealth)
                if newEnemies > 0 then
                    State.RaidState = "in_raid"
                    State.RaidLastCheck = now
                elseif now - State.RaidLastCheck >= 15 then
                    State.RaidState = "checking"
                    State.RaidSnapshot = nil
                    State.RaidLastCheck = now
                end

            elseif State.RaidState == "in_raid" then
                local newEnemies = CountNewLiveEnemiesNearby(State.RaidSnapshot or {}, 150, State.RaidMinHealth)
                if newEnemies == 0 then
                    State.RaidState = "checking"
                    State.RaidSnapshot = nil
                    State.RaidLastCheck = now
                end
            end
        end)
    else
        UnregisterTimedFeature("AutoRaid")
        State.RaidState = "idle"
        State.RaidSnapshot = nil
    end
end

function ToggleKillAllRaid(state)
    if state then
        RegisterTimedFeature("KillAllRaid", 0.3, function()
            if not State.KillAllRaid then return end
            local hrp = GetHRP()
            if not hrp then return end
            local enemies = GetEnemies()
            if not enemies then return end
            local closest, shortest = nil, math.huge
            for _, mob in ipairs(enemies:GetChildren()) do
                local mh = mob:FindFirstChildOfClass("Humanoid")
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if mh and mhrp and mh.Health > 0 then
                    local d = (mhrp.Position - hrp.Position).Magnitude
                    if d < shortest then
                        shortest = d
                        closest = mob
                    end
                end
            end
            if closest and closest:FindFirstChild("HumanoidRootPart") then
                hrp.CFrame = CFrame.new(closest.HumanoidRootPart.Position + Vector3.new(0, 3, 0))
                ActivateTool()
            end
        end)
    else
        UnregisterTimedFeature("KillAllRaid")
    end
end

function ToggleAutoNextIsland(state)
    if state then
        RegisterTimedFeature("AutoNextIsland", 4, function()
            if not State.AutoNextIsland then return end
            if not State.AutoRaid then return end
            if State.RaidState ~= "in_raid" then return end
            local commF = GetCommF()
            if not commF then return end
            pcall(function() commF:InvokeServer("Raids", "NextIsland") end)
        end)
    else
        UnregisterTimedFeature("AutoNextIsland")
    end
end

function ToggleAutoFish(state)
    if state then
        RegisterTimedFeature("AutoFish", 0.5, function()
            if not State.AutoFish then return end
            local char = GetChar()
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if not tool or not tool.Name:lower():find("rod") then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if backpack then
                    for _, bTool in ipairs(backpack:GetChildren()) do
                        if bTool:IsA("Tool") and bTool.Name:lower():find("rod") then
                            local hum = GetHum()
                            if hum then pcall(function() hum:EquipTool(bTool) end) end
                            tool = bTool
                            break
                        end
                    end
                end
            end
            if tool and tool.Name:lower():find("rod") then
                pcall(function() tool:Activate() end)
            end
        end)
    else
        UnregisterTimedFeature("AutoFish")
    end
end

function ToggleSeaBeastFarm(state)
    if state then
        RegisterTimedFeature("SeaBeastFarm", 0.3, function()
            if not State.SeaBeastFarm then return end
            local hrp = GetHRP()
            if not hrp then return end
            local seaBeasts = Workspace:FindFirstChild("SeaBeasts")
            if not seaBeasts then return end
            local closest, shortest = nil, math.huge
            for _, beast in ipairs(seaBeasts:GetChildren()) do
                local mh = beast:FindFirstChildOfClass("Humanoid")
                local bhrp = beast:FindFirstChild("HumanoidRootPart")
                if bhrp and (not mh or mh.Health > 0) then
                    local d = (bhrp.Position - hrp.Position).Magnitude
                    if d < shortest then
                        shortest = d
                        closest = beast
                    end
                end
            end
            if closest then
                local bhrp = closest:FindFirstChild("HumanoidRootPart")
                if bhrp then
                    hrp.CFrame = CFrame.new(bhrp.Position + Vector3.new(0, 5, 0))
                    ActivateTool()
                end
            end
        end)
    else
        UnregisterTimedFeature("SeaBeastFarm")
    end
end

function TeleportSeaBeast()
    local hrp = GetHRP()
    if not hrp then return end
    local seaBeasts = Workspace:FindFirstChild("SeaBeasts")
    if not seaBeasts then return end
    for _, beast in ipairs(seaBeasts:GetChildren()) do
        local bhrp = beast:FindFirstChild("HumanoidRootPart")
        if bhrp then
            hrp.CFrame = CFrame.new(bhrp.Position + Vector3.new(0, 5, 0))
            return
        end
    end
end

function SpawnBoat()
    local commF = GetCommF()
    if not commF then return end
    pcall(function() commF:InvokeServer("SpawnBoat") end)
end

local OriginalMaterials = {}
local OriginalLighting = { HasBackup = false }

local function ApplyFPSBoostToPart(obj)
    if not State.FPSBoost then return end
    if not obj:IsA("BasePart") then return end
    if OriginalMaterials[obj] ~= nil then return end
    OriginalMaterials[obj] = obj.Material
    pcall(function() obj.Material = Enum.Material.SmoothPlastic end)
end

AddConnection("FPSBoost_NewPart", Workspace.DescendantAdded, function(obj)
    if not State.FPSBoost then return end
    if obj:IsA("BasePart") then
        task.defer(function()
            if State.FPSBoost and obj.Parent then
                ApplyFPSBoostToPart(obj)
            end
        end)
    end
end)

function ToggleFPSBoost(state)
    if state then
        if State.FPSBoostActive then return end
        State.FPSBoostActive = true
        OriginalLighting.GlobalShadows = Lighting.GlobalShadows
        OriginalLighting.FogEnd = Lighting.FogEnd
        OriginalLighting.HasBackup = true
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        table.clear(OriginalMaterials)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            ApplyFPSBoostToPart(obj)
        end
    else
        if not State.FPSBoostActive then return end
        State.FPSBoostActive = false
        if OriginalLighting.HasBackup then
            pcall(function()
                Lighting.GlobalShadows = OriginalLighting.GlobalShadows
                Lighting.FogEnd = OriginalLighting.FogEnd
            end)
            OriginalLighting.HasBackup = false
        end
        for obj, mat in pairs(OriginalMaterials) do
            if obj and obj.Parent then
                pcall(function() obj.Material = mat end)
            end
        end
        table.clear(OriginalMaterials)
    end
end

function ServerHop()
    pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        if servers and servers.data then
            for _, s in pairs(servers.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    break
                end
            end
        end
    end)
end

AddConnection("Respawn", LocalPlayer.CharacterAdded, function(char)
    task.wait(0.5)
    if State.Destroyed then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        State.BaseWalkSpeed = hum.WalkSpeed
        State.BaseJumpPower = hum.JumpPower
    end
    if State.Noclip then ToggleNoclip(true) end
    if State.Fly then
        task.wait(0.5)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if hrp then SetupFly(hrp) end
    end
end)

local DragState = {active = nil, startPress = Vector2.new(0,0), offset = Vector2.new(0,0), moved = false}

local function BeginDrag(target, input)
    DragState.active = target
    DragState.startPress = Vector2.new(input.Position.X, input.Position.Y)
    local obj = (target == "main") and MainFrame or ToggleButton
    DragState.offset = Vector2.new(obj.AbsolutePosition.X, obj.AbsolutePosition.Y) - DragState.startPress
    DragState.moved = false
end

AddConnection("DragChanged", UserInputService.InputChanged, function(input)
    if State.Destroyed or not DragState.active then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local ma = Vector2.new(input.Position.X, input.Position.Y)
        if (ma - DragState.startPress).Magnitude > 3 then DragState.moved = true end
        local obj = (DragState.active == "main") and MainFrame or ToggleButton
        obj.Position = UDim2.fromOffset((ma + DragState.offset).X, (ma + DragState.offset).Y)
    end
end)

AddConnection("DragEnded", UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local wa = DragState.active
        local wm = DragState.moved
        DragState.active = nil
        if wa == "main" and wm then
            State.UserHasDragged = true
        elseif wa == "logo" and not wm and not State.Destroyed then
            local isOpen = MainFrame.Visible and MainFrame.Size.X.Offset > 50
            if isOpen then
                Tween(MainFrame, 0.2, { Size = UDim2.fromOffset(0, 0) })
                task.wait(0.2)
                if not State.Destroyed then MainFrame.Visible = false end
            else
                MainFrame.Visible = true
                MainFrame.Size = UDim2.fromOffset(0, 0)
                Tween(MainFrame, 0.25, { Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT) })
            end
        end
    end
end)

Header.InputBegan:Connect(function(input)
    if State.Destroyed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local headerAbs = Header.AbsolutePosition
        local headerSize = Header.AbsoluteSize
        local mx = input.Position.X
        if mx >= headerAbs.X + headerSize.X - 200 then return end
        BeginDrag("main", input)
    end
end)
ToggleButton.InputBegan:Connect(function(input)
    if State.Destroyed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        BeginDrag("logo", input)
    end
end)
CloseBtn.MouseButton1Click:Connect(function()
    if State.Destroyed then return end
    Tween(MainFrame, 0.2, { Size = UDim2.fromOffset(0, 0) })
    task.wait(0.2)
    if not State.Destroyed then MainFrame.Visible = false end
end)

function Cleanup()
    if State.Destroyed then return end
    State.Destroyed = true

    State.AutoFarm = false
    State.AutoChest = false
    State.AutoBone = false
    State.AutoMastery = false
    State.AutoQuest = false
    State.KillAura = false
    State.BringMob = false
    State.FruitSniper = false
    State.AutoStoreFruit = false
    State.ESPFruit = false
    State.AutoRaid = false
    State.KillAllRaid = false
    State.AutoNextIsland = false
    State.AutoFish = false
    State.SeaBeastFarm = false
    State.ESPPlayer = false
    State.ESPEnemy = false
    State.Noclip = false
    State.Fly = false
    State.FastWalk = false
    State.MoonJump = false
    State.FPSBoost = false
    State.AntiAFK = false
    State.RaidState = "idle"
    State.RaidSnapshot = nil
    State.ActiveFarmTarget = nil
    State.QuestState = "idle"

    if State.ActiveDropdown then
        pcall(State.ActiveDropdown)
        State.ActiveDropdown = nil
    end

    ActiveTimed = {}

    if ActiveTween then
        pcall(function() ActiveTween:Cancel() end)
        ActiveTween = nil
        LastTweenTarget = nil
    end

    local hum = GetHum()
    if hum then
        pcall(function()
            hum.WalkSpeed = State.BaseWalkSpeed
            hum.JumpPower = State.BaseJumpPower
            hum.AutoRotate = true
        end)
    end

    local hrp = GetHRP()
    if hrp then
        for _, n in ipairs({"SGVA_FlyAttach", "SGVA_FlyLV", "SGVA_OrientAttach", "SGVA_FlyAO"}) do
            local o = hrp:FindFirstChild(n)
            if o then o:Destroy() end
        end
    end

    for _, name in pairs(ESPNames) do
        ClearESPByName(name)
    end

    if OriginalLighting.HasBackup then
        pcall(function()
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows
            Lighting.FogEnd = OriginalLighting.FogEnd
        end)
        OriginalLighting.HasBackup = false
    end
    for obj, mat in pairs(OriginalMaterials) do
        if obj and obj.Parent then pcall(function() obj.Material = mat end) end
    end
    table.clear(OriginalMaterials)

    if State.CreditsPopup and State.CreditsPopup.Parent then
        State.CreditsPopup:Destroy()
        State.CreditsPopup = nil
    end

    if _G.SGVA_SwitchTab == SwitchTab then
        _G.SGVA_SwitchTab = nil
    end

    DisconnectAll()
    if ScreenGui then ScreenGui:Destroy() end

    print("[SGVA-BF] Unloaded")
end

GlobalEnv.SGVA_BF_Cleanup = Cleanup

task.wait(0.5)
if State.Destroyed then return end

ToggleAntiAFK(true)

local hum = GetHum()
if hum then
    State.BaseWalkSpeed = hum.WalkSpeed
    State.BaseJumpPower = hum.JumpPower
end

print("[SGVA-BF] Loaded v8. Developer: SAGA")
