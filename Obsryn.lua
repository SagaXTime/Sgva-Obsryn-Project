-- SGVA BLOX FRUITS HUB
-- DEVELOPER: SAGA
-- VERSION: Starter Kit + Fase 2 + Fase 3
-- UI: Quantum Onyx Style

print("[SGVA-BF] SCRIPT START")

-- ============================================================
-- SAFE ENVIRONMENT
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local GlobalEnv
if getgenv then
    local ok, env = pcall(getgenv)
    GlobalEnv = (ok and env) or _G
else
    GlobalEnv = _G
end

if GlobalEnv.SGVA_BF_Cleanup then
    pcall(GlobalEnv.SGVA_BF_Cleanup)
end

-- ============================================================
-- UI PARENT
-- ============================================================
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
if not UIParent then
    warn("[SGVA-BF] No UI parent.")
    return
end

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

-- ============================================================
-- THEME (Quantum Onyx style)
-- ============================================================
local Theme = {
    Background = Color3.fromRGB(8, 12, 24),
    Header = Color3.fromRGB(12, 18, 36),
    Panel = Color3.fromRGB(14, 22, 42),
    PanelLight = Color3.fromRGB(20, 30, 54),
    PanelAccent = Color3.fromRGB(26, 40, 68),
    Accent = Color3.fromRGB(60, 130, 255),
    AccentGlow = Color3.fromRGB(100, 180, 255),
    AccentDark = Color3.fromRGB(30, 70, 160),
    Purple = Color3.fromRGB(120, 100, 220),
    Green = Color3.fromRGB(0, 220, 130),
    Red = Color3.fromRGB(255, 70, 90),
    Yellow = Color3.fromRGB(255, 200, 0),
    Text = Color3.fromRGB(230, 240, 255),
    TextDim = Color3.fromRGB(130, 150, 190),
    TextDark = Color3.fromRGB(80, 100, 140),
    Divider = Color3.fromRGB(30, 45, 75),
    ToggleOn = Color3.fromRGB(60, 130, 255),
    ToggleOff = Color3.fromRGB(30, 40, 60)
}

-- ============================================================
-- STATE
-- ============================================================
local State = {
    -- Farm
    AutoFarm = false,
    AutoChest = false,
    AutoBone = false,
    AutoMastery = false,
    AutoQuest = false,
    MobHealth = 50,
    FarmDistance = 18,
    TweenSpeed = 250,
    BringRadius = 350,
    AutoFarmMode = "Nearest",
    SelectedWeapon = "Melee",
    
    -- Fruit
    FruitSniper = false,
    AutoStoreFruit = false,
    ESPFruit = false,
    SelectedFruit = "None",
    
    -- Raid
    AutoRaid = false,
    KillAllRaid = false,
    AutoNextIsland = false,
    RaidChip = "Flame",
    
    -- Sea
    AutoFish = false,
    SeaBeastFarm = false,
    AutoRaceV3 = false,
    AutoRaceV4 = false,
    
    -- Player
    ESPPlayer = false,
    ESPEnemy = false,
    Noclip = false,
    Fly = false,
    FlySpeed = 80,
    FastWalk = false,
    WalkSpeed = 50,
    MoonJump = false,
    JumpPower = 150,
    
    -- Misc
    AntiAFK = true,
    FPSBoost = false,
    
    -- Runtime
    Destroyed = false,
    UserHasDragged = false,
    BallsFolderCache = nil,
    FruitFolderCache = nil,
    Connections = {},
    FeatureConns = {},
    BaseWalkSpeed = 16,
    BaseJumpPower = 50,
    ActiveTab = "Farm",
    NotifCount = 0
}

-- ============================================================
-- CONNECTION MANAGER
-- ============================================================
local function AddConn(name, signal, callback)
    if State.Connections[name] then
        pcall(function() State.Connections[name]:Disconnect() end)
    end
    State.Connections[name] = signal:Connect(callback)
    return State.Connections[name]
end

local function RemoveConn(name)
    if State.Connections[name] then
        pcall(function() State.Connections[name]:Disconnect() end)
        State.Connections[name] = nil
    end
end

local function AddFeature(name, signal, callback)
    if State.FeatureConns[name] then
        pcall(function() State.FeatureConns[name]:Disconnect() end)
    end
    State.FeatureConns[name] = signal:Connect(callback)
    return State.FeatureConns[name]
end

local function RemoveFeature(name)
    if State.FeatureConns[name] then
        pcall(function() State.FeatureConns[name]:Disconnect() end)
        State.FeatureConns[name] = nil
    end
end

local function DisconnectAll()
    for _, conn in pairs(State.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    State.Connections = {}
    for _, conn in pairs(State.FeatureConns) do
        pcall(function() conn:Disconnect() end)
    end
    State.FeatureConns = {}
end

-- ============================================================
-- HELPERS
-- ============================================================
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

local function GetChar()
    return LocalPlayer.Character
end

local function GetHRP()
    local char = GetChar()
    if char then return char:FindFirstChild("HumanoidRootPart") end
end

local function GetHum()
    local char = GetChar()
    if char then return char:FindFirstChildOfClass("Humanoid") end
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local ScreenGui = Create("ScreenGui", {
    Name = "SGVA_BLOX_FRUITS",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 100
})

if not ScreenGui then
    warn("[SGVA-BF] Cannot create ScreenGui.")
    return
end

local parentOK = pcall(function() ScreenGui.Parent = UIParent end)
if not parentOK or not ScreenGui.Parent then
    pcall(function() ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end)
end

-- ============================================================
-- FLOATING LOGO (minimize button)
-- ============================================================
local ToggleButton = Create("TextButton", {
    Name = "SGVA_Logo",
    Size = UDim2.fromOffset(52, 52),
    Position = UDim2.fromOffset(20, 150),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Parent = ScreenGui
})
Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ToggleButton })
Create("UIStroke", { Color = Theme.AccentGlow, Thickness = 2, Parent = ToggleButton })
Create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "BF",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    ZIndex = 2,
    Parent = ToggleButton
})

-- ============================================================
-- MAIN FRAME
-- ============================================================
local MainFrame = Create("Frame", {
    Name = "MainFrame",
    Size = UDim2.fromOffset(640, 420),
    Position = UDim2.new(0.5, -320, 0.5, -210),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    Parent = ScreenGui
})
Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = MainFrame })
Create("UIStroke", { Color = Theme.Accent, Thickness = 1.5, Transparency = 0.4, Parent = MainFrame })

-- ============================================================
-- HEADER (mirip Quantum Onyx)
-- ============================================================
local Header = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = Theme.Header,
    BorderSizePixel = 0,
    Parent = MainFrame
})
Create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = Header })
Create("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = Theme.Header,
    BorderSizePixel = 0,
    Parent = Header
})

Create("TextLabel", {
    Size = UDim2.new(0, 250, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "SGVA BLOX FRUITS",
    TextColor3 = Theme.AccentGlow,
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = Header
})

-- Header buttons (kanan)
local HeaderBtnContainer = Create("Frame", {
    Size = UDim2.new(0, 130, 1, 0),
    Position = UDim2.new(1, -130, 0, 0),
    BackgroundTransparency = 1,
    Parent = Header
})

local function CreateHeaderBtn(text, w, callback)
    local btn = Create("TextButton", {
        Size = UDim2.fromOffset(w, 24),
        BackgroundColor3 = Theme.PanelAccent,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        AutoButtonColor = false,
        Parent = HeaderBtnContainer
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = btn })
    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    return btn
end

local CreditsBtn = CreateHeaderBtn("Credits", 48, function()
    print("[SGVA-BF] Credits: SAGA")
end)

local SettingsBtn = CreateHeaderBtn("Settings", 55, function()
    -- Switch to Misc tab
    if _G.SGVA_SwitchTab then _G.SGVA_SwitchTab("Misc") end
end)

local CloseBtn = Create("TextButton", {
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -26, 0, 7),
    BackgroundColor3 = Theme.Red,
    BackgroundTransparency = 0.6,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    AutoButtonColor = false,
    Parent = Header
})
Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = CloseBtn })

-- Layout header buttons
local headerBtnLayout = Create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4),
    Parent = HeaderBtnContainer
})
Create("UIPadding", { PaddingRight = UDim.new(0, 6), Parent = HeaderBtnContainer })

-- ============================================================
-- SEARCH BAR
-- ============================================================
local SearchBar = Create("Frame", {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, 44),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    Parent = MainFrame
})
Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = SearchBar })
Create("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = SearchBar })

Create("TextLabel", {
    Size = UDim2.fromOffset(24, 26),
    Position = UDim2.fromOffset(6, 0),
    BackgroundTransparency = 1,
    Text = "🔍",
    TextColor3 = Theme.TextDim,
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Parent = SearchBar
})

local SearchBox = Create("TextBox", {
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.fromOffset(28, 0),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "Search...",
    PlaceholderColor3 = Theme.TextDark,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Parent = SearchBar
})

-- ============================================================
-- TAB BAR
-- ============================================================
local TabBar = Create("Frame", {
    Size = UDim2.new(1, -20, 0, 28),
    Position = UDim2.new(0, 10, 0, 74),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    Parent = MainFrame
})
Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = TabBar })
Create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Parent = TabBar
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
        content.Visible = (cname == name)
    end
    State.ActiveTab = name
end

_G.SGVA_SwitchTab = SwitchTab

for _, name in ipairs(tabList) do
    local tabBtn = Create("TextButton", {
        Size = UDim2.fromOffset(78, 22),
        BackgroundColor3 = Theme.PanelAccent,
        BorderSizePixel = 0,
        Text = name,
        TextColor3 = Theme.TextDim,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        AutoButtonColor = false,
        Parent = TabBar
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = tabBtn })
    Tabs[name] = tabBtn
    
    tabBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        SwitchTab(name)
    end)
end

-- ============================================================
-- CONTENT AREA (left + right panel)
-- ============================================================
local ContentArea = Create("Frame", {
    Size = UDim2.new(1, -20, 1, -110),
    Position = UDim2.new(0, 10, 0, 106),
    BackgroundTransparency = 1,
    Parent = MainFrame
})

-- Kiri panel (toggles)
local LeftPanel = Create("Frame", {
    Size = UDim2.new(0.5, -4, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    Parent = ContentArea
})
Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = LeftPanel })
Create("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = LeftPanel })

-- Kanan panel (settings)
local RightPanel = Create("Frame", {
    Size = UDim2.new(0.5, -4, 1, 0),
    Position = UDim2.new(0.5, 4, 0, 0),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel = 0,
    Parent = ContentArea
})
Create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = RightPanel })
Create("UIStroke", { Color = Theme.Divider, Thickness = 1, Parent = RightPanel })

-- ============================================================
-- TAB CONTENT BUILDER
-- ============================================================
-- Setiap tab punya 2 panel: left (toggles), right (settings)
local function CreateTabContent(name)
    local leftScroll = Create("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        Parent = LeftPanel
    })
    Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = leftScroll })
    
    local rightScroll = Create("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -12),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        Parent = RightPanel
    })
    Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rightScroll })
    
    local content = { left = leftScroll, right = rightScroll }
    TabContents[name] = content
    return content
end

-- ============================================================
-- COMPONENTS
-- ============================================================
local function CreateSection(parent, title)
    local sec = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = Theme.PanelAccent,
        BorderSizePixel = 0,
        Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = sec })
    Create("Frame", {
        Size = UDim2.new(0, 3, 0.55, 0),
        Position = UDim2.new(0, 6, 0.22, 0),
        BackgroundColor3 = Theme.AccentGlow,
        BorderSizePixel = 0,
        Parent = sec
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.AccentGlow,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sec
    })
    return sec
end

local function CreateToggle(parent, text, default, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.PanelLight,
        BorderSizePixel = 0,
        Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = frame })
    
    Create("TextLabel", {
        Size = UDim2.new(0.7, 0, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })
    
    local btn = Create("TextButton", {
        Size = UDim2.fromOffset(34, 16),
        Position = UDim2.new(1, -42, 0.5, -8),
        BackgroundColor3 = default and Theme.ToggleOn or Theme.ToggleOff,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = frame
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = btn })
    
    local knob = Create("Frame", {
        Size = UDim2.fromOffset(12, 12),
        Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = btn
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
    
    local isOn = default
    btn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        isOn = not isOn
        Tween(btn, 0.15, { BackgroundColor3 = isOn and Theme.ToggleOn or Theme.ToggleOff })
        Tween(knob, 0.15, { Position = isOn and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) })
        if callback then callback(isOn) end
    end)
    
    return frame
end

local function CreateSlider(parent, text, min, max, default, suffix, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.PanelLight,
        BorderSizePixel = 0,
        Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = frame })
    
    Create("TextLabel", {
        Size = UDim2.new(0.6, 0, 0, 16),
        Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = frame
    })
    
    local valueBox = Create("TextLabel", {
        Size = UDim2.fromOffset(50, 16),
        Position = UDim2.new(1, -60, 0, 4),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Text = tostring(default),
        TextColor3 = Theme.AccentGlow,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        Parent = frame
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = valueBox })
    
    local barBg = Create("Frame", {
        Size = UDim2.new(1, -20, 0, 5),
        Position = UDim2.new(0, 10, 0, 26),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Parent = frame
    })
    Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBg })
    
    local barFill = Create("Frame", {
        Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = barBg
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
        valueBox.Text = tostring(value)
        if callback then callback(value) end
    end
    
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    
    local sliderId = "S_" .. tostring(math.random(1, 9999999))
    AddConn(sliderId .. "_c", UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    AddConn(sliderId .. "_e", UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    return frame
end

local function CreateButton(parent, text, callback)
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.AccentDark,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        AutoButtonColor = false,
        Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = btn })
    Create("UIStroke", { Color = Theme.Accent, Thickness = 1, Transparency = 0.5, Parent = btn })
    
    btn.MouseEnter:Connect(function() Tween(btn, 0.1, { BackgroundColor3 = Theme.Accent }) end)
    btn.MouseLeave:Connect(function() Tween(btn, 0.1, { BackgroundColor3 = Theme.AccentDark }) end)
    btn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        if callback then callback() end
    end)
    return btn
end

local function CreateDropdown(parent, text, options, callback)
    local frame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Theme.PanelLight,
        BorderSizePixel = 0,
        Parent = parent
    })
    Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = frame })
    
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text .. ": " .. options[1],
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        Parent = frame
    })
    Create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = btn })
    
    if callback then callback(options[1]) end
    
    local isOpen = false
    local optFrame
    btn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        isOpen = not isOpen
        if isOpen then
            optFrame = Create("Frame", {
                Size = UDim2.new(1, 0, 0, #options * 22),
                Position = UDim2.new(0, 0, 1, 2),
                BackgroundColor3 = Theme.PanelAccent,
                BorderSizePixel = 0,
                ZIndex = 20,
                Parent = frame
            })
            Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = optFrame })
            Create("UIStroke", { Color = Theme.Accent, Thickness = 1, Parent = optFrame })
            
            for i, opt in ipairs(options) do
                local optBtn = Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 22),
                    Position = UDim2.new(0, 0, 0, (i-1) * 22),
                    BackgroundTransparency = 1,
                    Text = opt,
                    TextColor3 = Theme.Text,
                    Font = Enum.Font.Gotham,
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 21,
                    AutoButtonColor = false,
                    Parent = optFrame
                })
                Create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = optBtn })
                optBtn.MouseButton1Click:Connect(function()
                    btn.Text = text .. ": " .. opt
                    if callback then callback(opt) end
                    optFrame:Destroy()
                    isOpen = false
                end)
            end
        else
            if optFrame then optFrame:Destroy() end
            isOpen = false
        end
    end)
    
    return frame
end

-- ============================================================
-- BUILD TABS
-- ============================================================
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
CreateDropdown(FarmTab.right, "Weapon", {"Melee", "Sword", "Gun", "Fruit"}, function(v) State.SelectedWeapon = v end)
CreateSlider(FarmTab.right, "Mob Health %", 10, 100, 50, "%", function(v) State.MobHealth = v end)
CreateSlider(FarmTab.right, "Farm Distance", 10, 100, 18, "s", function(v) State.FarmDistance = v end)
CreateSlider(FarmTab.right, "Tween Speed", 50, 500, 250, "", function(v) State.TweenSpeed = v end)
CreateSlider(FarmTab.right, "Bring Radius", 50, 1000, 350, "s", function(v) State.BringRadius = v end)

local FruitTab = CreateTabContent("Fruit")
CreateSection(FruitTab.left, "FRUIT TOGGLES")
CreateToggle(FruitTab.left, "Fruit Sniper", false, function(v) State.FruitSniper = v; ToggleFruitSniper(v) end)
CreateToggle(FruitTab.left, "Auto Store Fruit", false, function(v) State.AutoStoreFruit = v; ToggleAutoStoreFruit(v) end)
CreateToggle(FruitTab.left, "ESP Fruit", false, function(v) State.ESPFruit = v; ToggleESPFruit(v) end)
CreateToggle(FruitTab.left, "Auto Buy Fruit", false, function(v) State.AutoBuyFruit = v end)

CreateSection(FruitTab.right, "FRUIT SETTINGS")
CreateDropdown(FruitTab.right, "Select Fruit", {"Rocket", "Spin", "Blade", "Spring", "Bomb", "Smoke", "Spike", "Flame", "Falcon", "Ice", "Sand", "Dark", "Diamond", "Light", "Rubber", "Barrier", "Ghost", "Magma", "Quake", "Buddha", "Love", "Spider", "Sound", "Phoenix", "Portal", "Rumble", "Pain", "Blizzard", "Gravity", "Mammoth", "T-Rex", "Dough", "Shadow", "Venom", "Control", "Spirit", "Dragon", "Leopard", "Kitsune"}, function(v) State.SelectedFruit = v end)
CreateButton(FruitTab.right, "Teleport to Selected Fruit", function()
    TeleportToFruit(State.SelectedFruit)
end)

local RaidTab = CreateTabContent("Raid")
CreateSection(RaidTab.left, "RAID TOGGLES")
CreateToggle(RaidTab.left, "Auto Raid", false, function(v) State.AutoRaid = v; ToggleAutoRaid(v) end)
CreateToggle(RaidTab.left, "Kill All Raid NPCs", false, function(v) State.KillAllRaid = v; ToggleKillAllRaid(v) end)
CreateToggle(RaidTab.left, "Auto Next Island", false, function(v) State.AutoNextIsland = v; ToggleAutoNextIsland(v) end)

CreateSection(RaidTab.right, "RAID SETTINGS")
CreateDropdown(RaidTab.right, "Raid Chip", {"Flame", "Ice", "Quake", "Light", "Dark", "Spider", "Rumble", "Magma", "Buddha", "Love", "Creation", "Spirit", "Portal", "Blizzard", "Pain", "Dough", "Shadow", "Venom", "Control", "Gravity"}, function(v) State.RaidChip = v end)
CreateButton(RaidTab.right, "Buy Raid Chip", function() BuyRaidChip(State.RaidChip) end)
CreateButton(RaidTab.right, "Start Raid", function() StartRaid() end)
CreateButton(RaidTab.right, "Teleport to Raid Island", function() TeleportRaidIsland() end)

local SeaTab = CreateTabContent("Sea")
CreateSection(SeaTab.left, "SEA TOGGLES")
CreateToggle(SeaTab.left, "Auto Fish", false, function(v) State.AutoFish = v; ToggleAutoFish(v) end)
CreateToggle(SeaTab.left, "Sea Beast Farm", false, function(v) State.SeaBeastFarm = v; ToggleSeaBeastFarm(v) end)
CreateToggle(SeaTab.left, "Auto Race V3", false, function(v) State.AutoRaceV3 = v; ToggleAutoRaceV3(v) end)
CreateToggle(SeaTab.left, "Auto Race V4", false, function(v) State.AutoRaceV4 = v; ToggleAutoRaceV4(v) end)

CreateSection(SeaTab.right, "SEA INFO")
CreateButton(SeaTab.right, "Teleport to Sea Beast", function() TeleportSeaBeast() end)
CreateButton(SeaTab.right, "Auto Sail Boat", function() AutoSailBoat() end)

local PlayerTab = CreateTabContent("Player")
CreateSection(PlayerTab.left, "PLAYER TOGGLES")
CreateToggle(PlayerTab.left, "ESP Player", false, function(v) State.ESPPlayer = v; ToggleESPPlayer(v) end)
CreateToggle(PlayerTab.left, "ESP Enemy", false, function(v) State.ESPEnemy = v; ToggleESPEnemy(v) end)
CreateToggle(PlayerTab.left, "Noclip", false, function(v) State.Noclip = v; ToggleNoclip(v) end)
CreateToggle(PlayerTab.left, "Fly", false, function(v) State.Fly = v; ToggleFly(v) end)
CreateToggle(PlayerTab.left, "Fast Walk", false, function(v) State.FastWalk = v; ToggleFastWalk(v) end)
CreateToggle(PlayerTab.left, "Moon Jump", false, function(v) State.MoonJump = v; ToggleMoonJump(v) end)
CreateToggle(PlayerTab.left, "Infinite Energy", false, function(v) State.InfEnergy = v; ToggleInfEnergy(v) end)

CreateSection(PlayerTab.right, "PLAYER SETTINGS")
CreateSlider(PlayerTab.right, "Fly Speed", 10, 300, 80, "", function(v) State.FlySpeed = v end)
CreateSlider(PlayerTab.right, "Walk Speed", 16, 300, 50, "", function(v) State.WalkSpeed = v end)
CreateSlider(PlayerTab.right, "Jump Power", 50, 500, 150, "", function(v) State.JumpPower = v end)

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
    local char = GetChar()
    if char then char:BreakJoints() end
end)
CreateButton(MiscTab.right, "Unload Script", function() Cleanup() end)

-- Set default tab
SwitchTab("Farm")

-- ============================================================
-- FEATURE IMPLEMENTATIONS
-- ============================================================

-- Helper: get enemies folder
local function GetEnemies()
    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then return enemies end
    return Workspace:FindFirstChild("enemies")
end

-- Helper: get chests
local function GetChests()
    local chests = Workspace:FindFirstChild("Chests")
    if chests then return chests end
    return Workspace:FindFirstChild("chests")
end

-- Teleport function
local function TeleportTo(pos)
    local hrp = GetHRP()
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos)
end

-- Attack function
local function AttackNearest()
    local char = GetChar()
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
    end
end

-- ANTI AFK
function ToggleAntiAFK(state)
    if state then
        AddFeature("AntiAFK", LocalPlayer.Idled, function()
            if not State.AntiAFK then return end
            if VirtualUser then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end)
    else
        RemoveFeature("AntiAFK")
    end
end

-- NOCLIP
local NoclipOriginal = {}
function ToggleNoclip(state)
    if state then
        local char = GetChar()
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    NoclipOriginal[v] = v.CanCollide
                    v.CanCollide = false
                end
            end
        end
        AddFeature("Noclip", RunService.Stepped, function()
            if not State.Noclip then return end
            local c = GetChar()
            if c then
                for _, v in pairs(c:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        if NoclipOriginal[v] == nil then NoclipOriginal[v] = true end
                        v.CanCollide = false
                    end
                end
            end
        end)
    else
        RemoveFeature("Noclip")
        for obj, val in pairs(NoclipOriginal) do
            if obj and obj.Parent then pcall(function() obj.CanCollide = val end) end
        end
        NoclipOriginal = {}
    end
end

-- FLY (camera mode)
local FlyBV, FlyBG
local function SetupFly(hrp)
    if not hrp then return end
    if hrp:FindFirstChild("SGVA_FlyBV") then hrp.SGVA_FlyBV:Destroy() end
    if hrp:FindFirstChild("SGVA_FlyBG") then hrp.SGVA_FlyBG:Destroy() end
    FlyBV = Instance.new("BodyVelocity")
    FlyBV.Name = "SGVA_FlyBV"
    FlyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    FlyBV.Velocity = Vector3.zero
    FlyBV.Parent = hrp
    FlyBG = Instance.new("BodyGyro")
    FlyBG.Name = "SGVA_FlyBG"
    FlyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    FlyBG.P = 10000
    FlyBG.D = 500
    FlyBG.Parent = hrp
end

function ToggleFly(state)
    if state then
        local hrp = GetHRP()
        if hrp then SetupFly(hrp) end
        AddFeature("Fly", RunService.PreSimulation, function()
            if not State.Fly then return end
            local char = GetChar()
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp then return end
            if not hrp:FindFirstChild("SGVA_FlyBV") or not hrp:FindFirstChild("SGVA_FlyBG") then
                SetupFly(hrp)
            end
            FlyBV = hrp:FindFirstChild("SGVA_FlyBV")
            FlyBG = hrp:FindFirstChild("SGVA_FlyBG")
            if not FlyBV or not FlyBG then return end
            local cam = Workspace.CurrentCamera
            if not cam then return end
            if hum then hum.AutoRotate = false end
            local camCF = cam.CFrame
            local look = camCF.LookVector
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + camCF.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0,1,0) end
            if hum and hum.MoveDirection.Magnitude > 0.1 then
                move = hum.MoveDirection + Vector3.new(0, move.Y, 0)
            end
            if move.Magnitude > 0 then
                FlyBV.Velocity = move.Unit * State.FlySpeed
            else
                FlyBV.Velocity = Vector3.zero
            end
            FlyBG.CFrame = camCF
        end)
    else
        RemoveFeature("Fly")
        local hrp = GetHRP()
        if hrp then
            if hrp:FindFirstChild("SGVA_FlyBV") then hrp.SGVA_FlyBV:Destroy() end
            if hrp:FindFirstChild("SGVA_FlyBG") then hrp.SGVA_FlyBG:Destroy() end
        end
        local hum = GetHum()
        if hum then hum.AutoRotate = true end
    end
end

-- FAST WALK
function ToggleFastWalk(state)
    if state then
        AddFeature("FastWalk", RunService.Heartbeat, function()
            if not State.FastWalk then return end
            local hum = GetHum()
            if hum then hum.WalkSpeed = State.WalkSpeed end
        end)
    else
        RemoveFeature("FastWalk")
        local hum = GetHum()
        if hum then hum.WalkSpeed = State.BaseWalkSpeed end
    end
end

-- MOON JUMP
function ToggleMoonJump(state)
    if state then
        AddFeature("MoonJump", RunService.Heartbeat, function()
            if not State.MoonJump then return end
            local hum = GetHum()
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = State.JumpPower
            end
        end)
    else
        RemoveFeature("MoonJump")
        local hum = GetHum()
        if hum then hum.JumpPower = State.BaseJumpPower end
    end
end

-- INFINITE ENERGY
function ToggleInfEnergy(state)
    if state then
        AddFeature("InfEnergy", RunService.Heartbeat, function()
            if not State.InfEnergy then return end
            local char = GetChar()
            if char then
                local energy = char:FindFirstChild("Energy")
                if energy then energy.Value = energy.MaxValue or 100 end
            end
        end)
    else
        RemoveFeature("InfEnergy")
    end
end

-- AUTO FARM
function ToggleAutoFarm(state)
    if state then
        AddFeature("AutoFarm", RunService.Heartbeat, function()
            if not State.AutoFarm then return end
            local char = GetChar()
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local enemies = GetEnemies()
            if not enemies then return end
            local closest, dist = nil, State.FarmDistance
            for _, mob in ipairs(enemies:GetChildren()) do
                if mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChildOfClass("Humanoid") then
                    local h = mob:FindFirstChildOfClass("Humanoid")
                    if h.Health > 0 then
                        local d = (mob.HumanoidRootPart.Position - hrp.Position).Magnitude
                        if d < dist then
                            dist = d
                            closest = mob
                        end
                    end
                end
            end
            if closest then
                hrp.CFrame = CFrame.new(closest.HumanoidRootPart.Position + Vector3.new(0, 5, 0))
                AttackNearest()
            end
        end)
    else
        RemoveFeature("AutoFarm")
    end
end

-- AUTO CHEST
function ToggleAutoChest(state)
    if state then
        AddFeature("AutoChest", RunService.Heartbeat, function()
            if not State.AutoChest then return end
            local hrp = GetHRP()
            if not hrp then return end
            local chests = GetChests()
            if not chests then return end
            for _, chest in ipairs(chests:GetChildren()) do
                if chest:IsA("BasePart") or chest:IsA("Model") then
                    local part = chest:IsA("BasePart") and chest or chest.PrimaryPart or chest:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local d = (part.Position - hrp.Position).Magnitude
                        if d < 500 then
                            hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                            task.wait(0.15)
                        end
                    end
                end
            end
        end)
    else
        RemoveFeature("AutoChest")
    end
end

-- AUTO BONE
function ToggleAutoBone(state)
    if state then
        AddFeature("AutoBone", RunService.Heartbeat, function()
            if not State.AutoBone then return end
            local hrp = GetHRP()
            if not hrp then return end
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name:lower():find("bone") and obj:IsA("BasePart") then
                    local d = (obj.Position - hrp.Position).Magnitude
                    if d < 500 then
                        hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0))
                        task.wait(0.15)
                    end
                end
            end
        end)
    else
        RemoveFeature("AutoBone")
    end
end

-- AUTO MASTERY (auto use tool)
function ToggleAutoMastery(state)
    if state then
        AddFeature("AutoMastery", RunService.Heartbeat, function()
            if not State.AutoMastery then return end
            AttackNearest()
        end)
    else
        RemoveFeature("AutoMastery")
    end
end

-- AUTO QUEST
function ToggleAutoQuest(state)
    if state then
        AddFeature("AutoQuest", RunService.Heartbeat, function()
            if not State.AutoQuest then return end
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
                if commF then
                    commF:InvokeServer("StartQuest")
                end
            end)
        end)
    else
        RemoveFeature("AutoQuest")
    end
end

-- KILL AURA
function ToggleKillAura(state)
    if state then
        AddFeature("KillAura", RunService.Heartbeat, function()
            if not State.KillAura then return end
            AttackNearest()
        end)
    else
        RemoveFeature("KillAura")
    end
end

-- BRING MOB
function ToggleBringMob(state)
    if state then
        AddFeature("BringMob", RunService.Heartbeat, function()
            if not State.BringMob then return end
            local hrp = GetHRP()
            if not hrp then return end
            local enemies = GetEnemies()
            if not enemies then return end
            for _, mob in ipairs(enemies:GetChildren()) do
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if mhrp then
                    local d = (mhrp.Position - hrp.Position).Magnitude
                    if d < State.BringRadius and d > 3 then
                        mhrp.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
                    end
                end
            end
        end)
    else
        RemoveFeature("BringMob")
    end
end

-- ESP
local ESPSystem = {}
local function CreateESP(part, color)
    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.6
    hl.Name = "SGVA_ESP"
    hl.Parent = part
    return hl
end

function ToggleESPFruit(state)
    if state then
        AddFeature("ESPFruit", RunService.Heartbeat, function()
            if not State.ESPFruit then return end
            for _, v in ipairs(Workspace:GetChildren()) do
                if v:IsA("Tool") and v:FindFirstChild("Handle") then
                    if not v.Handle:FindFirstChild("SGVA_ESP") then
                        CreateESP(v.Handle, Color3.fromRGB(255, 200, 0))
                    end
                end
            end
        end)
    else
        RemoveFeature("ESPFruit")
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name == "SGVA_ESP" then v:Destroy() end
        end
    end
end

function ToggleESPEnemy(state)
    if state then
        AddFeature("ESPEnemy", RunService.Heartbeat, function()
            if not State.ESPEnemy then return end
            local enemies = GetEnemies()
            if not enemies then return end
            for _, mob in ipairs(enemies:GetChildren()) do
                local hrp = mob:FindFirstChild("HumanoidRootPart")
                if hrp and not hrp:FindFirstChild("SGVA_ESP") then
                    CreateESP(hrp, Color3.fromRGB(255, 60, 90))
                end
            end
        end)
    else
        RemoveFeature("ESPEnemy")
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name == "SGVA_ESP" then v:Destroy() end
        end
    end
end

function ToggleESPPlayer(state)
    if state then
        AddFeature("ESPPlayer", RunService.Heartbeat, function()
            if not State.ESPPlayer then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and not hrp:FindFirstChild("SGVA_ESP") then
                        CreateESP(hrp, Color3.fromRGB(0, 220, 130))
                    end
                end
            end
        end)
    else
        RemoveFeature("ESPPlayer")
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name == "SGVA_ESP" then v:Destroy() end
        end
    end
end

-- FRUIT SNIPER
function ToggleFruitSniper(state)
    if state then
        AddFeature("FruitSniper", RunService.Heartbeat, function()
            if not State.FruitSniper then return end
            local hrp = GetHRP()
            if not hrp then return end
            for _, v in ipairs(Workspace:GetChildren()) do
                if v:IsA("Tool") and v:FindFirstChild("Handle") then
                    hrp.CFrame = CFrame.new(v.Handle.Position + Vector3.new(0, 3, 0))
                    task.wait(0.3)
                end
            end
        end)
    else
        RemoveFeature("FruitSniper")
    end
end

function ToggleAutoStoreFruit(state)
    if state then
        AddFeature("AutoStoreFruit", RunService.Heartbeat, function()
            if not State.AutoStoreFruit then return end
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
                if commF then
                    commF:InvokeServer("StoreFruit")
                end
            end)
        end)
    else
        RemoveFeature("AutoStoreFruit")
    end
end

function TeleportToFruit(fruitName)
    local hrp = GetHRP()
    if not hrp then return end
    for _, v in ipairs(Workspace:GetChildren()) do
        if v:IsA("Tool") and v.Name:lower():find(fruitName:lower()) and v:FindFirstChild("Handle") then
            hrp.CFrame = CFrame.new(v.Handle.Position + Vector3.new(0, 3, 0))
            return
        end
    end
end

-- RAID
function BuyRaidChip(fruit)
    pcall(function()
        local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
        if commF then
            commF:InvokeServer("Raids", 1, fruit)
        end
    end)
end

function StartRaid()
    pcall(function()
        local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
        if commF then
            commF:InvokeServer("Raids", 2)
        end
    end)
end

function TeleportRaidIsland()
    local hrp = GetHRP()
    if not hrp then return end
    pcall(function()
        local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
        if commF then
            commF:InvokeServer("requestEntrance", "CursedShip")
        end
    end)
end

function ToggleAutoRaid(state)
    if state then
        AddFeature("AutoRaid", RunService.Heartbeat, function()
            if not State.AutoRaid then return end
            StartRaid()
            task.wait(5)
        end)
    else
        RemoveFeature("AutoRaid")
    end
end

function ToggleKillAllRaid(state)
    if state then
        AddFeature("KillAllRaid", RunService.Heartbeat, function()
            if not State.KillAllRaid then return end
            local hrp = GetHRP()
            if not hrp then return end
            local enemies = GetEnemies()
            if not enemies then return end
            for _, mob in ipairs(enemies:GetChildren()) do
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if mhrp and mob:FindFirstChildOfClass("Humanoid") then
                    if mob:FindFirstChildOfClass("Humanoid").Health > 0 then
                        hrp.CFrame = CFrame.new(mhrp.Position + Vector3.new(0, 3, 0))
                        AttackNearest()
                    end
                end
            end
        end)
    else
        RemoveFeature("KillAllRaid")
    end
end

function ToggleAutoNextIsland(state)
    if state then
        AddFeature("AutoNextIsland", RunService.Heartbeat, function()
            if not State.AutoNextIsland then return end
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
                if commF then
                    commF:InvokeServer("Raids", "NextIsland")
                end
            end)
            task.wait(3)
        end)
    else
        RemoveFeature("AutoNextIsland")
    end
end

-- SEA
function ToggleAutoFish(state)
    if state then
        AddFeature("AutoFish", RunService.Heartbeat, function()
            if not State.AutoFish then return end
            local char = GetChar()
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and tool.Name:lower():find("rod") then
                pcall(function() tool:Activate() end)
            end
            task.wait(0.5)
        end)
    else
        RemoveFeature("AutoFish")
    end
end

function ToggleSeaBeastFarm(state)
    if state then
        AddFeature("SeaBeastFarm", RunService.Heartbeat, function()
            if not State.SeaBeastFarm then return end
            local hrp = GetHRP()
            if not hrp then return end
            local seaBeasts = Workspace:FindFirstChild("SeaBeasts")
            if seaBeasts then
                for _, beast in ipairs(seaBeasts:GetChildren()) do
                    local bhrp = beast:FindFirstChild("HumanoidRootPart")
                    if bhrp then
                        hrp.CFrame = CFrame.new(bhrp.Position + Vector3.new(0, 5, 0))
                        AttackNearest()
                    end
                end
            end
        end)
    else
        RemoveFeature("SeaBeastFarm")
    end
end

function TeleportSeaBeast()
    local hrp = GetHRP()
    if not hrp then return end
    local seaBeasts = Workspace:FindFirstChild("SeaBeasts")
    if seaBeasts then
        for _, beast in ipairs(seaBeasts:GetChildren()) do
            local bhrp = beast:FindFirstChild("HumanoidRootPart")
            if bhrp then
                hrp.CFrame = CFrame.new(bhrp.Position + Vector3.new(0, 5, 0))
                return
            end
        end
    end
end

function AutoSailBoat()
    pcall(function()
        local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
        if commF then
            commF:InvokeServer("SpawnBoat")
        end
    end)
end

function ToggleAutoRaceV3(state)
    if state then
        AddFeature("AutoRaceV3", RunService.Heartbeat, function()
            if not State.AutoRaceV3 then return end
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
                if commF then
                    commF:InvokeServer("Race", "Start", "V3")
                end
            end)
            task.wait(5)
        end)
    else
        RemoveFeature("AutoRaceV3")
    end
end

function ToggleAutoRaceV4(state)
    if state then
        AddFeature("AutoRaceV4", RunService.Heartbeat, function()
            if not State.AutoRaceV4 then return end
            pcall(function()
                local commF = ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("CommF_")
                if commF then
                    commF:InvokeServer("Race", "Start", "V4")
                end
            end)
            task.wait(5)
        end)
    else
        RemoveFeature("AutoRaceV4")
    end
end

-- FPS BOOST
function ToggleFPSBoost(state)
    if state then
        pcall(function()
            game.Lighting.GlobalShadows = false
            game.Lighting.FogEnd = 9e9
            for _, v in pairs(Workspace:GetDescendants()) do
                if v:IsA("BasePart") and v.Material ~= Enum.Material.SmoothPlastic then
                    pcall(function() v.Material = Enum.Material.SmoothPlastic end)
                end
            end
        end)
    end
end

-- SERVER HOP
function ServerHop()
    pcall(function()
        local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
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

-- ============================================================
-- DRAG SYSTEM
-- ============================================================
local DragState = {active = nil, startPress = Vector2.new(0,0), offset = Vector2.new(0,0), moved = false}

local function BeginDrag(target, input)
    DragState.active = target
    DragState.startPress = Vector2.new(input.Position.X, input.Position.Y)
    local obj = (target == "main") and MainFrame or ToggleButton
    DragState.offset = Vector2.new(obj.AbsolutePosition.X, obj.AbsolutePosition.Y) - DragState.startPress
    DragState.moved = false
end

AddConn("DragChanged", UserInputService.InputChanged, function(input)
    if State.Destroyed or not DragState.active then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local ma = Vector2.new(input.Position.X, input.Position.Y)
        if (ma - DragState.startPress).Magnitude > 3 then DragState.moved = true end
        local obj = (DragState.active == "main") and MainFrame or ToggleButton
        local newPos = ma + DragState.offset
        obj.Position = UDim2.fromOffset(newPos.X, newPos.Y)
    end
end)

AddConn("DragEnded", UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local wasActive = DragState.active
        local wasMoved = DragState.moved
        DragState.active = nil
        if wasActive == "main" and wasMoved then
            State.UserHasDragged = true
        elseif wasActive == "logo" and not wasMoved and not State.Destroyed then
            local isOpen = MainFrame.Visible and MainFrame.Size.X.Offset > 50
            if isOpen then
                Tween(MainFrame, 0.2, { Size = UDim2.fromOffset(0, 0) })
                task.wait(0.2)
                if not State.Destroyed then MainFrame.Visible = false end
            else
                MainFrame.Visible = true
                MainFrame.Size = UDim2.fromOffset(0, 0)
                Tween(MainFrame, 0.25, { Size = UDim2.fromOffset(640, 420) })
            end
        end
    end
end)

Header.InputBegan:Connect(function(input)
    if State.Destroyed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

-- ============================================================
-- AUTO-CANVAS SIZE
-- ============================================================
local function UpdateCanvas(scroll)
    local layout = scroll:FindFirstChildOfClass("UIListLayout")
    if layout then
        scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
    end
end

AddConn("CanvasFarmL", RunService.Heartbeat, function()
    if TabContents["Farm"] and TabContents["Farm"].left then UpdateCanvas(TabContents["Farm"].left) end
    if TabContents["Farm"] and TabContents["Farm"].right then UpdateCanvas(TabContents["Farm"].right) end
    if TabContents["Fruit"] and TabContents["Fruit"].left then UpdateCanvas(TabContents["Fruit"].left) end
    if TabContents["Fruit"] and TabContents["Fruit"].right then UpdateCanvas(TabContents["Fruit"].right) end
end)

-- ============================================================
-- CHARACTER RESPAWN HANDLER
-- ============================================================
AddConn("Respawn", LocalPlayer.CharacterAdded, function(char)
    task.wait(0.5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        State.BaseWalkSpeed = hum.WalkSpeed
        State.BaseJumpPower = hum.JumpPower
    end
    if State.Noclip then ToggleNoclip(true) end
    if State.Fly then ToggleFly(true) end
end)

-- ============================================================
-- CLEANUP
-- ============================================================
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
    State.AutoRaceV3 = false
    State.AutoRaceV4 = false
    State.ESPPlayer = false
    State.ESPEnemy = false
    State.Noclip = false
    State.Fly = false
    State.FastWalk = false
    State.MoonJump = false
    State.InfEnergy = false
    
    -- Restore state
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
        for _, name in ipairs({"SGVA_FlyBV", "SGVA_FlyBG"}) do
            local obj = hrp:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
    end
    
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "SGVA_ESP" then pcall(function() v:Destroy() end) end
    end
    
    DisconnectAll()
    if ScreenGui then ScreenGui:Destroy() end
    
    print("[SGVA-BF] Script unloaded")
end

GlobalEnv.SGVA_BF_Cleanup = Cleanup

-- ============================================================
-- INITIALIZATION
-- ============================================================
task.wait(0.5)

-- Default Anti-AFK ON
ToggleAntiAFK(true)

-- Initial humanoid capture
local hum = GetHum()
if hum then
    State.BaseWalkSpeed = hum.WalkSpeed
    State.BaseJumpPower = hum.JumpPower
end

print("[SGVA-BF] Script loaded. Developer: SAGA")
