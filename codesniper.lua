--[[
    Code Sniper (Announcement Edition) + UI — LamByy System
    Слушает анонсы (RemoteEvent NotificationService/Notify)
    и автоматически вводит промокод по триггеру.
    Для инжектора/экзекутера. UI создаётся скриптом, игру не трогает.
]]

-- ══════════════════════════════════════════════════════════════════
--  НАСТРОЙКИ ПО УМОЛЧАНИЮ (можно менять в UI на лету)
-- ══════════════════════════════════════════════════════════════════
local DEFAULTS = {
    Trigger    = "code is:",  -- фраза-триггер (регистр не важен)
    Offset     = 0,           -- сколько слов после триггера пропустить
    MaxWords   = 1,           -- сколько слов склеить в код (0 = весь остаток)
    AutoRedeem = true,        -- автоматически вводить код
    Cooldown   = 2,           -- кулдаун между разными кодами (сек)
    Dedup      = 15,          -- не вводить один код дважды за N секунд
    Debug      = false,       -- печатать все анонсы в лог
    Ignore     = { "is", "code", ":", "the", "new", "promo", "promocode" }, -- слова-мусор после триггера
}

local CONFIG = table.clone(DEFAULTS)

-- ══════════════════════════════════════════════════════════════════
--  ЗАВИСИМОСТИ
-- ══════════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- ── Net и ремоуты ─────────────────────────────────────────────────
local Net
pcall(function()
    Net = require(ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("Net", 10))
end)

local NotifyRemote, RedeemRemote

if Net then
    NotifyRemote = Net:RemoteEvent("NotificationService/Notify")
    RedeemRemote = Net:RemoteFunction("RequestRedemption")
else
    local function find(className, name)
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA(className) and v.Name == name then return v end
        end
    end
    NotifyRemote = find("RemoteEvent", "NotificationService/Notify")
    RedeemRemote = find("RemoteFunction", "RequestRedemption")
end

if not NotifyRemote then
    warn("[CodeSniper] Не найден RemoteEvent NotificationService/Notify")
    return
end
if not RedeemRemote then
    warn("[CodeSniper] Не найден RemoteFunction RequestRedemption — авто-ввод выключен")
    CONFIG.AutoRedeem = false
end

-- ══════════════════════════════════════════════════════════════════
--  ПАРСЕР КОДА
-- ══════════════════════════════════════════════════════════════════
local function isIgnored(w)
    local lw = string.lower(w)
    for _, x in ipairs(CONFIG.Ignore) do
        if lw == x then return true end
    end
    return false
end

local function extractCode(text)
    if type(text) ~= "string" or text == "" then return nil end
    if CONFIG.Trigger == "" then return nil end

    local low      = string.lower(text)
    local trigger  = string.lower(CONFIG.Trigger)
    local startPos = string.find(low, trigger, 1, true)
    if not startPos then return nil end

    local after = string.sub(text, startPos + #trigger)
    local words = {}
    for w in string.gmatch(after, "%S+") do
        words[#words + 1] = w
    end

    -- пропускаем слова-мусор в начале
    local idx = 1
    while idx <= #words and isIgnored(words[idx]) do
        idx += 1
    end
    idx += CONFIG.Offset

    if idx > #words then return nil end

    local picked = {}
    local last = (CONFIG.MaxWords > 0)
        and math.min(idx + CONFIG.MaxWords - 1, #words)
        or  #words

    for i = idx, last do
        picked[#picked + 1] = words[i]
    end

    local code = string.upper(string.gsub(table.concat(picked, ""), "[^%w]", ""))
    return #code > 0 and code or nil
end

-- ══════════════════════════════════════════════════════════════════
--  UI
-- ══════════════════════════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "CodeSniperUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 320, 0, 420)
main.Position = UDim2.new(0.5, -160, 0.5, -210)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(60, 60, 70)
mainStroke.Thickness = 1
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Text = "  🎯 Code Sniper"
title.Size = UDim2.new(1, -80, 1, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(230, 230, 240)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local hideBtn = Instance.new("TextButton")
hideBtn.Text = "—"
hideBtn.Size = UDim2.new(0, 28, 0, 22)
hideBtn.Position = UDim2.new(1, -60, 0, 6)
hideBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
hideBtn.BorderSizePixel = 0
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 14
hideBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
hideBtn.Parent = header

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 6)
hideCorner.Parent = hideBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "✕"
closeBtn.Size = UDim2.new(0, 28, 0, 22)
closeBtn.Position = UDim2.new(1, -28, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 35)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local settings = Instance.new("Frame")
settings.Name = "Settings"
settings.Size = UDim2.new(1, -20, 0, 210)
settings.Position = UDim2.new(0, 10, 0, 44)
settings.BackgroundTransparency = 1
settings.Parent = main

local function makeRow(order, labelText)
    local row = Instance.new("Frame")
    row.Name = labelText
    row.Size = UDim2.new(1, 0, 0, 28)
    row.Position = UDim2.new(0, 0, 0, order * 30)
    row.BackgroundTransparency = 1
    row.Parent = settings

    local lbl = Instance.new("TextLabel")
    lbl.Text = labelText
    lbl.Size = UDim2.new(0, 120, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(190, 190, 200)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    return row, lbl
end

local function makeTextBox(order, labelText, default)
    local row = makeRow(order, labelText)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -125, 0, 24)
    box.Position = UDim2.new(0, 122, 0, 2)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = Color3.fromRGB(230, 230, 240)
    box.PlaceholderText = "…"
    box.Text = tostring(default)
    box.ClearTextOnFocus = false
    box.Parent = row

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = box

    return box
end

local function makeToggle(order, labelText, default)
    local row = makeRow(order, labelText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 52, 0, 24)
    btn.Position = UDim2.new(1, -54, 0, 2)
    btn.BackgroundColor3 = default and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(60, 35, 40)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(240, 240, 240)
    btn.Text = default and "ON" or "OFF"
    btn.Parent = row

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(60, 35, 40)
    end)

    return btn, function() return state end
end

local triggerBox = makeTextBox(0, "Триггер:", CONFIG.Trigger)
local offsetBox  = makeTextBox(1, "Пропуск слов:", CONFIG.Offset)
local maxBox     = makeTextBox(2, "Слов в коде:", CONFIG.MaxWords)
local coolBox    = makeTextBox(3, "Кулдаун (сек):", CONFIG.Cooldown)
local dedupBox   = makeTextBox(4, "Дедуп (сек):", CONFIG.Dedup)

local autoBtn, getAuto = makeToggle(5, "Авто-ввод:", CONFIG.AutoRedeem)
local dbgBtn, getDbg   = makeToggle(6, "Debug лог:", CONFIG.Debug)

local function applySettings()
    CONFIG.Trigger  = triggerBox.Text ~= "" and triggerBox.Text or "code is:"
    CONFIG.Offset   = math.max(0, math.floor(tonumber(offsetBox.Text) or 0))
    CONFIG.MaxWords = math.max(0, math.floor(tonumber(maxBox.Text) or 0))
    CONFIG.Cooldown = math.max(0, tonumber(coolBox.Text) or 0)
    CONFIG.Dedup    = math.max(0, tonumber(dedupBox.Text) or 0)
    CONFIG.AutoRedeem = getAuto()
    CONFIG.Debug      = getDbg()

    offsetBox.Text = tostring(CONFIG.Offset)
    maxBox.Text    = tostring(CONFIG.MaxWords)
    coolBox.Text   = tostring(CONFIG.Cooldown)
    dedupBox.Text  = tostring(CONFIG.Dedup)
end

for _, box in ipairs({triggerBox, offsetBox, maxBox, coolBox, dedupBox}) do
    box.FocusLost:Connect(applySettings)
end
autoBtn.MouseButton1Click:Connect(function() task.wait() applySettings() end)
dbgBtn.MouseButton1Click:Connect(function() task.wait() applySettings() end)

local resetBtn = Instance.new("TextButton")
resetBtn.Text = "Сбросить настройки"
resetBtn.Size = UDim2.new(1, 0, 0, 24)
resetBtn.Position = UDim2.new(0, 0, 0, 216)
resetBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
resetBtn.BorderSizePixel = 0
resetBtn.Font = Enum.Font.Gotham
resetBtn.TextSize = 11
resetBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
resetBtn.Parent = settings

local rc = Instance.new("UICorner")
rc.CornerRadius = UDim.new(0, 6)
rc.Parent = resetBtn

resetBtn.MouseButton1Click:Connect(function()
    triggerBox.Text = DEFAULTS.Trigger
    offsetBox.Text  = tostring(DEFAULTS.Offset)
    maxBox.Text     = tostring(DEFAULTS.MaxWords)
    coolBox.Text    = tostring(DEFAULTS.Cooldown)
    dedupBox.Text   = tostring(DEFAULTS.Dedup)
    applySettings()
end)

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 0, 268)
divider.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
divider.BorderSizePixel = 0
divider.Parent = main

local logTitle = Instance.new("TextLabel")
logTitle.Text = "  Лог"
logTitle.Size = UDim2.new(1, -20, 0, 18)
logTitle.Position = UDim2.new(0, 10, 0, 274)
logTitle.BackgroundTransparency = 1
logTitle.Font = Enum.Font.GothamBold
logTitle.TextSize = 11
logTitle.TextColor3 = Color3.fromRGB(160, 160, 175)
logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.Parent = main

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -20, 0, 92)
logScroll.Position = UDim2.new(0, 10, 0, 294)
logScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 4
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.Parent = main

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 6)
logCorner.Parent = logScroll

local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 2)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logScroll

local logPadding = Instance.new("UIPadding")
logPadding.PaddingTop = UDim.new(0, 4)
logPadding.PaddingLeft = UDim.new(0, 6)
logPadding.PaddingRight = UDim.new(0, 6)
logPadding.Parent = logScroll

local logIndex = 0
local function log(text, color)
    logIndex += 1
    local entry = Instance.new("TextLabel")
    entry.Size = UDim2.new(1, -12, 0, 14)
    entry.BackgroundTransparency = 1
    entry.Font = Enum.Font.Code
    entry.TextSize = 11
    entry.TextColor3 = color or Color3.fromRGB(180, 220, 180)
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.TextWrapped = false
    entry.Text = "[*] " .. tostring(text)
    entry.LayoutOrder = logIndex
    entry.Parent = logScroll

    local children = logScroll:GetChildren()
    local entries = {}
    for _, c in ipairs(children) do
        if c:IsA("TextLabel") then entries[#entries + 1] = c end
    end
    if #entries > 60 then
        entries[1]:Destroy()
    end
end

local manualBox = Instance.new("TextBox")
manualBox.Size = UDim2.new(1, -80, 0, 26)
manualBox.Position = UDim2.new(0, 10, 1, -32)
manualBox.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
manualBox.BorderSizePixel = 0
manualBox.Font = Enum.Font.Gotham
manualBox.TextSize = 12
manualBox.TextColor3 = Color3.fromRGB(230, 230, 240)
manualBox.PlaceholderText = "Ввести код вручную…"
manualBox.Text = ""
manualBox.ClearTextOnFocus = false
manualBox.Parent = main

local mbc = Instance.new("UICorner")
mbc.CornerRadius = UDim.new(0, 6)
mbc.Parent = manualBox

local manualBtn = Instance.new("TextButton")
manualBtn.Text = "Ввод"
manualBtn.Size = UDim2.new(0, 60, 0, 26)
manualBtn.Position = UDim2.new(1, -70, 1, -32)
manualBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 140)
manualBtn.BorderSizePixel = 0
manualBtn.Font = Enum.Font.GothamBold
manualBtn.TextSize = 11
manualBtn.TextColor3 = Color3.fromRGB(240, 240, 250)
manualBtn.Parent = main

local mbtnc = Instance.new("UICorner")
mbtnc.CornerRadius = UDim.new(0, 6)
mbtnc.Parent = manualBtn

local collapsed = false
local fullSize = UDim2.new(0, 320, 0, 420)
local miniSize = UDim2.new(0, 320, 0, 34)

hideBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    main.Size = collapsed and miniSize or fullSize
    hideBtn.Text = collapsed and "+" or "—"
end)

closeBtn.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    header.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════
--  ЛОГИКА РЕДИМА
-- ══════════════════════════════════════════════════════════════════
local lastCode, lastTime = nil, 0

local function redeem(code, source)
    if not RedeemRemote then
        log("RedeemRemote отсутствует", Color3.fromRGB(240, 120, 120))
        return
    end

    local now = os.clock()
    if now - lastTime < CONFIG.Cooldown then
        if CONFIG.Debug then log("Кулдаун, пропуск: " .. code, Color3.fromRGB(200, 180, 120)) end
        return
    end
    if code == lastCode and now - lastTime < CONFIG.Dedup then
        if CONFIG.Debug then log("Дубликат, пропуск: " .. code, Color3.fromRGB(200, 180, 120)) end
        return
    end

    lastCode, lastTime = code, now
    log("→ " .. code .. (source and (" (" .. source .. ")") or ""), Color3.fromRGB(140, 200, 255))

    task.spawn(function()
        local ok, result, msg = pcall(function()
            return RedeemRemote:InvokeServer(code)
        end)
        if not ok then
            log("✗ ошибка вызова", Color3.fromRGB(240, 120, 120))
        elseif result then
            log("✓ " .. tostring(msg or "успешно"), Color3.fromRGB(120, 230, 140))
        else
            log("✗ " .. tostring(msg or "отказ"), Color3.fromRGB(240, 150, 120))
        end
    end)
end

manualBtn.MouseButton1Click:Connect(function()
    local code = string.upper(string.gsub(manualBox.Text, "[^%w]", ""))
    if #code < 1 then
        log("Пустой код", Color3.fromRGB(240, 150, 120))
        return
    end
    manualBox.Text = ""
    redeem(code, "вручную")
end)
manualBox.FocusLost:Connect(function(enter)
    if enter then manualBtn:Fire() end
end)

-- ══════════════════════════════════════════════════════════════════
--  СЛУШАЕМ АНОНСЫ
-- ══════════════════════════════════════════════════════════════════
NotifyRemote.OnClientEvent:Connect(function(text)
    if CONFIG.Debug then
        log("анонс: " .. tostring(text), Color3.fromRGB(150, 150, 170))
    end

    local code = extractCode(text)
    if not code then return end

    log("найден: " .. code, Color3.fromRGB(230, 230, 150))

    if CONFIG.AutoRedeem then
        redeem(code, "анонс")
    end
end)

log("Скрипт запущен. Триггер: " .. CONFIG.Trigger, Color3.fromRGB(180, 220, 180))
log("Жду анонсы…", Color3.fromRGB(150, 150, 170))
