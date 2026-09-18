--[[
    Code Sniper (Announcement Edition) + UI — LamByy System — v3.1
    Убирает HTML-теги (<phantom> и пр.), берёт код после ":" во втором анонсе.
]]

local DEFAULTS = {
    Trigger    = "code is:",
    Offset     = 0,
    MaxWords   = 1,
    AutoRedeem = true,
    Cooldown   = 2,
    Dedup      = 15,
    Debug      = false,
    WaitNext   = true,
    WaitTime   = 20,
    Ignore     = { "is", "code", ":", "the", "new", "promo", "promocode", "rainbow", "phantom" },
}
local CONFIG = table.clone(DEFAULTS)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

local Net
pcall(function()
    Net = require(ReplicatedStorage:WaitForChild("Packages", 10):WaitForChild("Net", 10))
end)
local NotifyRemote, RedeemRemote
if Net then
    NotifyRemote = Net:RemoteEvent("NotificationService/Notify")
    RedeemRemote = Net:RemoteFunction("RequestRedemption")
else
    local function find(c, n) for _, v in ipairs(ReplicatedStorage:GetDescendants()) do if v:IsA(c) and v.Name == n then return v end end end
    NotifyRemote = find("RemoteEvent", "NotificationService/Notify")
    RedeemRemote = find("RemoteFunction", "RequestRedemption")
end
if not NotifyRemote then warn("[CodeSniper] нет RemoteEvent") return end
if not RedeemRemote then CONFIG.AutoRedeem = false end

local function stripTags(s)
    return (string.gsub(tostring(s), "<[^>]*>", ""))
end

local function isIgnored(w)
    local lw = string.lower(w)
    for _, x in ipairs(CONFIG.Ignore) do if lw == x then return true end end
    return false
end

local function cleanCode(s)
    local c = string.upper(string.gsub(tostring(s), "[^%w]", ""))
    return #c > 0 and c or nil
end

local function extractAfterTrigger(text)
    if type(text) ~= "string" or text == "" or CONFIG.Trigger == "" then return nil end
    text = stripTags(text)
    local low = string.lower(text)
    local s = string.find(low, string.lower(CONFIG.Trigger), 1, true)
    if not s then return nil end
    local after = string.sub(text, s + #CONFIG.Trigger)
    local words = {}
    for w in string.gmatch(after, "%S+") do words[#words + 1] = w end
    local idx = 1
    while idx <= #words and isIgnored(words[idx]) do idx += 1 end
    idx += CONFIG.Offset
    if idx > #words then return nil end
    local picked, last = {}, (CONFIG.MaxWords > 0) and math.min(idx + CONFIG.MaxWords - 1, #words) or #words
    for i = idx, last do picked[#picked + 1] = words[i] end
    return cleanCode(table.concat(picked, ""))
end

-- во втором анонсе берём текст ПОСЛЕ последнего ":" (это сам текст анонса, без имени отправителя)
local function firstMeaningfulWord(text)
    if type(text) ~= "string" then return nil end
    text = stripTags(text)
    local _, colonPos = string.find(text, ":[^:]*$")
    local body = colonPos and string.sub(text, colonPos + 1) or text
    local words = {}
    for w in string.gmatch(body, "%S+") do words[#words + 1] = w end
    for i = #words, 1, -1 do
        local w = words[i]
        if not isIgnored(w) then
            local c = cleanCode(w)
            if c then return c end
        end
    end
    return nil
end

local gui = Instance.new("ScreenGui")
gui.Name = "CodeSniperUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 320, 0, 450)
main.Position = UDim2.new(0.5, -160, 0.5, -225)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 10) mc.Parent = main
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(60, 60, 70) ms.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
header.BorderSizePixel = 0
header.Parent = main
local hc = Instance.new("UICorner") hc.CornerRadius = UDim.new(0, 10) hc.Parent = header
local hfix = Instance.new("Frame") hfix.Size = UDim2.new(1,0,0,10) hfix.Position = UDim2.new(0,0,1,-10) hfix.BackgroundColor3 = Color3.fromRGB(25,25,30) hfix.BorderSizePixel = 0 hfix.Parent = header

local title = Instance.new("TextLabel")
title.Text = "  🎯 Code Sniper v3.1"
title.Size = UDim2.new(1, -80, 1, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(230,230,240)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local hideBtn = Instance.new("TextButton")
hideBtn.Text = "—" hideBtn.Size = UDim2.new(0,28,0,22) hideBtn.Position = UDim2.new(1,-60,0,6)
hideBtn.BackgroundColor3 = Color3.fromRGB(40,40,48) hideBtn.BorderSizePixel = 0
hideBtn.Font = Enum.Font.GothamBold hideBtn.TextSize = 14 hideBtn.TextColor3 = Color3.fromRGB(230,230,240)
hideBtn.Parent = header
local hc2 = Instance.new("UICorner") hc2.CornerRadius = UDim.new(0,6) hc2.Parent = hideBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "✕" closeBtn.Size = UDim2.new(0,28,0,22) closeBtn.Position = UDim2.new(1,-28,0,6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60,30,35) closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold closeBtn.TextSize = 12 closeBtn.TextColor3 = Color3.fromRGB(255,180,180)
closeBtn.Parent = header
local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0,6) cc.Parent = closeBtn

local settings = Instance.new("Frame")
settings.Size = UDim2.new(1, -20, 0, 240)
settings.Position = UDim2.new(0, 10, 0, 44)
settings.BackgroundTransparency = 1
settings.Parent = main

local function makeRow(order, labelText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.Position = UDim2.new(0, 0, 0, order * 30)
    row.BackgroundTransparency = 1
    row.Parent = settings
    local lbl = Instance.new("TextLabel")
    lbl.Text = labelText lbl.Size = UDim2.new(0,120,1,0) lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham lbl.TextSize = 12 lbl.TextColor3 = Color3.fromRGB(190,190,200)
    lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Parent = row
    return row
end
local function makeTextBox(order, labelText, default)
    local row = makeRow(order, labelText)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1,-125,0,24) box.Position = UDim2.new(0,122,0,2)
    box.BackgroundColor3 = Color3.fromRGB(30,30,36) box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham box.TextSize = 12 box.TextColor3 = Color3.fromRGB(230,230,240)
    box.Text = tostring(default) box.ClearTextOnFocus = false box.Parent = row
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = box
    return box
end
local function makeToggle(order, labelText, default)
    local row = makeRow(order, labelText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,52,0,24) btn.Position = UDim2.new(1,-54,0,2)
    btn.BackgroundColor3 = default and Color3.fromRGB(40,120,70) or Color3.fromRGB(60,35,40)
    btn.BorderSizePixel = 0 btn.Font = Enum.Font.GothamBold btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(240,240,240) btn.Text = default and "ON" or "OFF" btn.Parent = row
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0,6) c.Parent = btn
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(40,120,70) or Color3.fromRGB(60,35,40)
    end)
    return btn, function() return state end
end

local triggerBox = makeTextBox(0, "Триггер:", CONFIG.Trigger)
local offsetBox  = makeTextBox(1, "Пропуск слов:", CONFIG.Offset)
local maxBox     = makeTextBox(2, "Слов в коде:", CONFIG.MaxWords)
local coolBox    = makeTextBox(3, "Кулдаун (сек):", CONFIG.Cooldown)
local dedupBox   = makeTextBox(4, "Дедуп (сек):", CONFIG.Dedup)
local autoBtn, getAuto = makeToggle(5, "Авто-ввод:", CONFIG.AutoRedeem)
local waitBtn, getWait = makeToggle(6, "Ждать след. анонс:", CONFIG.WaitNext)
local dbgBtn, getDbg   = makeToggle(7, "Debug лог:", CONFIG.Debug)

local function applySettings()
    CONFIG.Trigger  = triggerBox.Text ~= "" and triggerBox.Text or "code is:"
    CONFIG.Offset   = math.max(0, math.floor(tonumber(offsetBox.Text) or 0))
    CONFIG.MaxWords = math.max(0, math.floor(tonumber(maxBox.Text) or 0))
    CONFIG.Cooldown = math.max(0, tonumber(coolBox.Text) or 0)
    CONFIG.Dedup    = math.max(0, tonumber(dedupBox.Text) or 0)
    CONFIG.AutoRedeem = getAuto()
    CONFIG.WaitNext   = getWait()
    CONFIG.Debug      = getDbg()
end
for _, box in ipairs({triggerBox, offsetBox, maxBox, coolBox, dedupBox}) do
    box.FocusLost:Connect(applySettings)
end
autoBtn.MouseButton1Click:Connect(function() task.wait() applySettings() end)
waitBtn.MouseButton1Click:Connect(function() task.wait() applySettings() end)
dbgBtn.MouseButton1Click:Connect(function() task.wait() applySettings() end)

local resetBtn = Instance.new("TextButton")
resetBtn.Text = "Сбросить настройки"
resetBtn.Size = UDim2.new(1,0,0,24) resetBtn.Position = UDim2.new(0,0,0,246)
resetBtn.BackgroundColor3 = Color3.fromRGB(35,35,42) resetBtn.BorderSizePixel = 0
resetBtn.Font = Enum.Font.Gotham resetBtn.TextSize = 11 resetBtn.TextColor3 = Color3.fromRGB(200,200,210)
resetBtn.Parent = settings
local rcc = Instance.new("UICorner") rcc.CornerRadius = UDim.new(0,6) rcc.Parent = resetBtn
resetBtn.MouseButton1Click:Connect(function()
    triggerBox.Text = DEFAULTS.Trigger offsetBox.Text = tostring(DEFAULTS.Offset)
    maxBox.Text = tostring(DEFAULTS.MaxWords) coolBox.Text = tostring(DEFAULTS.Cooldown)
    dedupBox.Text = tostring(DEFAULTS.Dedup) applySettings()
end)

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1,-20,0,1) divider.Position = UDim2.new(0,10,0,298)
divider.BackgroundColor3 = Color3.fromRGB(50,50,60) divider.BorderSizePixel = 0 divider.Parent = main

local logTitle = Instance.new("TextLabel")
logTitle.Text = "  Лог" logTitle.Size = UDim2.new(1,-20,0,18) logTitle.Position = UDim2.new(0,10,0,304)
logTitle.BackgroundTransparency = 1 logTitle.Font = Enum.Font.GothamBold logTitle.TextSize = 11
logTitle.TextColor3 = Color3.fromRGB(160,160,175) logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.Parent = main

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1,-20,0,92) logScroll.Position = UDim2.new(0,10,0,324)
logScroll.BackgroundColor3 = Color3.fromRGB(12,12,15) logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 4 logScroll.CanvasSize = UDim2.new(0,0,0,0)
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y logScroll.Parent = main
local lgc = Instance.new("UICorner") lgc.CornerRadius = UDim.new(0,6) lgc.Parent = logScroll
local lgl = Instance.new("UIListLayout") lgl.Padding = UDim.new(0,2) lgl.SortOrder = Enum.SortOrder.LayoutOrder lgl.Parent = logScroll
local lgp = Instance.new("UIPadding") lgp.PaddingTop = UDim.new(0,4) lgp.PaddingLeft = UDim.new(0,6) lgp.PaddingRight = UDim.new(0,6) lgp.Parent = logScroll

local logIndex = 0
local function log(text, color)
    logIndex += 1
    local e = Instance.new("TextLabel")
    e.Size = UDim2.new(1,-12,0,14) e.BackgroundTransparency = 1
    e.Font = Enum.Font.Code e.TextSize = 11
    e.TextColor3 = color or Color3.fromRGB(180,220,180)
    e.TextXAlignment = Enum.TextXAlignment.Left e.TextWrapped = false
    e.Text = "[*] " .. tostring(text) e.LayoutOrder = logIndex e.Parent = logScroll
    local entries = {}
    for _, c in ipairs(logScroll:GetChildren()) do if c:IsA("TextLabel") then entries[#entries+1] = c end end
    if #entries > 60 then entries[1]:Destroy() end
end

local manualBox = Instance.new("TextBox")
manualBox.Size = UDim2.new(1,-80,0,26) manualBox.Position = UDim2.new(0,10,1,-32)
manualBox.BackgroundColor3 = Color3.fromRGB(30,30,36) manualBox.BorderSizePixel = 0
manualBox.Font = Enum.Font.Gotham manualBox.TextSize = 12 manualBox.TextColor3 = Color3.fromRGB(230,230,240)
manualBox.PlaceholderText = "Ввести код вручную…" manualBox.Text = "" manualBox.ClearTextOnFocus = false
manualBox.Parent = main
local mbc = Instance.new("UICorner") mbc.CornerRadius = UDim.new(0,6) mbc.Parent = manualBox

local manualBtn = Instance.new("TextButton")
manualBtn.Text = "Ввод" manualBtn.Size = UDim2.new(0,60,0,26) manualBtn.Position = UDim2.new(1,-70,1,-32)
manualBtn.BackgroundColor3 = Color3.fromRGB(40,90,140) manualBtn.BorderSizePixel = 0
manualBtn.Font = Enum.Font.GothamBold manualBtn.TextSize = 11 manualBtn.TextColor3 = Color3.fromRGB(240,240,250)
manualBtn.Parent = main
local mbtnc = Instance.new("UICorner") mbtnc.CornerRadius = UDim.new(0,6) mbtnc.Parent = manualBtn

local collapsed = false
local fullSize = UDim2.new(0, 320, 0, 450)
local miniSize = UDim2.new(0, 320, 0, 34)
hideBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    main.Size = collapsed and miniSize or fullSize
    hideBtn.Text = collapsed and "+" or "—"
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true dragStart = input.Position startPos = main.Position
        end
    end)
    header.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local lastCode, lastTime = nil, 0
local function redeem(code, source)
    if not RedeemRemote then log("RedeemRemote отсутствует", Color3.fromRGB(240,120,120)) return end
    local now = os.clock()
    if now - lastTime < CONFIG.Cooldown then return end
    if code == lastCode and now - lastTime < CONFIG.Dedup then return end
    lastCode, lastTime = code, now
    log("→ " .. code .. (source and (" (" .. source .. ")") or ""), Color3.fromRGB(140,200,255))
    task.spawn(function()
        local ok, result, msg = pcall(function() return RedeemRemote:InvokeServer(code) end)
        if not ok then log("✗ ошибка вызова", Color3.fromRGB(240,120,120))
        elseif result then log("✓ " .. tostring(msg or "успешно"), Color3.fromRGB(120,230,140))
        else log("✗ " .. tostring(msg or "отказ"), Color3.fromRGB(240,150,120)) end
    end)
end

manualBtn.MouseButton1Click:Connect(function()
    local code = cleanCode(manualBox.Text)
    if not code then log("Пустой код", Color3.fromRGB(240,150,120)) return end
    manualBox.Text = ""
    redeem(code, "вручную")
end)
manualBox.FocusLost:Connect(function(enter) if enter then manualBtn:Fire() end end)

local waitingForCode = false
local waitStarted = 0

NotifyRemote.OnClientEvent:Connect(function(text)
    text = tostring(text)
    if CONFIG.Debug then log("анонс: " .. text, Color3.fromRGB(150,150,170)) end

    local clean = stripTags(text)
    local low = string.lower(clean)
    local hasTrigger = string.find(low, string.lower(CONFIG.Trigger), 1, true) ~= nil

    if hasTrigger then
        local code = extractAfterTrigger(text)
        if code then
            log("найден: " .. code, Color3.fromRGB(230,230,150))
            if CONFIG.AutoRedeem then redeem(code, "анонс") end
            waitingForCode = false
            return
        end
        if CONFIG.WaitNext then
            waitingForCode = true
            waitStarted = os.clock()
            log("жду код в след. анонсе…", Color3.fromRGB(200,200,120))
        end
        return
    end

    if waitingForCode then
        if os.clock() - waitStarted > CONFIG.WaitTime then
            waitingForCode = false
            return
        end
        local code = firstMeaningfulWord(text)
        waitingForCode = false
        if code then
            log("найден: " .. code, Color3.fromRGB(230,230,150))
            if CONFIG.AutoRedeem then redeem(code, "след. анонс") end
        end
    end
end)

log("Скрипт запущен. Триггер: " .. CONFIG.Trigger, Color3.fromRGB(180,220,180))
log("Жду анонсы…", Color3.fromRGB(150,150,170))
