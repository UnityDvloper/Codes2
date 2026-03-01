local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

-- ══════════════════════════════════════════════
--  ESTADO
-- ══════════════════════════════════════════════
local Estado = {
    esp             = false,
    espTracers      = true,
    espTracerGross  = 12,
    espTracerTransp = 0.27,
    corESP          = Color3.fromRGB(132, 204, 21),
    hubFechado      = false,

    walkspeed       = 16,
    fly             = false,
    voarVel         = 50,
    noclip          = false,

    autofarm        = false,
    autofarmdiamond = false,
    autohoops       = false,
    autorebirth     = false,
}

-- ══════════════════════════════════════════════
--  STATS DE SESSÃO
-- ══════════════════════════════════════════════
local Sessao = {
    levelAcumulado = 0,
    levelAnterior  = 0,
    stepsInicio    = 0,
    hoopsInicio    = 0,
    gemsInicio     = 0,
    rebirthsIni    = 0,
    iniciado       = false,
}

local _consESP  = {}
local _espDados = {}
local _consFarm = {}

local function LimparConexoes(lista)
    for _, c in pairs(lista) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    table.clear(lista)
end

-- ══════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════
local function GetChar()
    return LocalPlayer.Character
end
local function GetHRP(plr)
    local char = plr and plr.Character or GetChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function GetHum(plr)
    local char = plr and plr.Character or GetChar()
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function WorldToViewport(pos)
    local vp, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vp.X, vp.Y), onScreen, vp.Z
end

local function GetLevelAtual()
    local ok, v = pcall(function()
        local txt = LocalPlayer.PlayerGui.gameGui.statsFrame.levelLabel.Text
        return tonumber(txt:match("%d+")) or 0
    end)
    return ok and v or 0
end

local function GetNeededLevel()
    local ok, v = pcall(function()
        local txt = LocalPlayer.PlayerGui.gameGui.rebirthMenu.neededLabel.amountLabel.Text
        return tonumber(txt:match("%d+")) or 0
    end)
    return ok and v or 0
end

local function GetGems()
    local ok, v = pcall(function() return LocalPlayer.Gems.Value end)
    return ok and v or 0
end

local function GetHoops()
    local ok, v = pcall(function() return LocalPlayer.leaderstats.Hoops.Value end)
    return ok and v or 0
end

local function GetSteps()
    local ok, v = pcall(function() return LocalPlayer.leaderstats.Steps.Value end)
    return ok and v or 0
end

local function GetRebirths()
    local ok, v = pcall(function() return LocalPlayer.leaderstats.Rebirths.Value end)
    return ok and v or 0
end

local function IniciarSessao()
    if Sessao.iniciado then return end
    Sessao.iniciado       = true
    Sessao.levelAnterior  = GetLevelAtual()
    Sessao.levelAcumulado = 0
    Sessao.stepsInicio    = GetSteps()
    Sessao.hoopsInicio    = GetHoops()
    Sessao.gemsInicio     = GetGems()
    Sessao.rebirthsIni    = GetRebirths()
end

-- ══════════════════════════════════════════════
--  LISTA DE JOGADORES (para dropdown de TP)
-- ══════════════════════════════════════════════
local function GetListaJogadores()
    local lista = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(lista, plr.Name)
        end
    end
    if #lista == 0 then
        table.insert(lista, "Nenhum jogador")
    end
    table.sort(lista)
    return lista
end

local function TeleportarPara(nome)
    local plr = Players:FindFirstChild(nome)
    if not plr or not plr.Character then
        return false
    end
    local hrpAlvo = plr.Character:FindFirstChild("HumanoidRootPart")
    local hrpMeu  = GetHRP()
    if not hrpAlvo or not hrpMeu then return false end
    hrpMeu.CFrame = hrpAlvo.CFrame * CFrame.new(0, 0, -3)
    return true
end

-- ══════════════════════════════════════════════
--  ESP — CRIAR / REMOVER
-- ══════════════════════════════════════════════
local function RemoverEntradaESP(nome)
    local d = _espDados[nome]
    if not d then return end
    if d.hl  and d.hl.Parent  then d.hl:Destroy() end
    if d.gui and d.gui.Parent then d.gui:Destroy() end
    if d.line then pcall(function() d.line:Remove() end) end
    _espDados[nome] = nil
end

local function CriarEntradaESP(plr)
    RemoverEntradaESP(plr.Name)
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local cor = Estado.corESP

    local hl = Instance.new("Highlight")
    hl.FillColor           = cor
    hl.OutlineColor        = Color3.new(1,1,1)
    hl.FillTransparency    = 0.45
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = char
    hl.Parent              = char

    local gui = Instance.new("BillboardGui")
    gui.AlwaysOnTop = true
    gui.Size        = UDim2.new(0, 130, 0, 56)
    gui.StudsOffset = Vector3.new(0, 3.2, 0)
    gui.Adornee     = hrp
    gui.Parent      = hrp

    local bg = Instance.new("Frame")
    bg.Size                   = UDim2.new(1,0,1,0)
    bg.BackgroundColor3       = Color3.fromRGB(8,8,12)
    bg.BackgroundTransparency = 0.42
    bg.BorderSizePixel        = 0
    bg.Parent                 = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,6)
    corner.Parent       = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color        = cor
    stroke.Thickness    = 1
    stroke.Transparency = 0.25
    stroke.Parent       = bg

    local lblNome = Instance.new("TextLabel")
    lblNome.Size                   = UDim2.new(1,-8,0,16)
    lblNome.Position               = UDim2.new(0,4,0,4)
    lblNome.BackgroundTransparency = 1
    lblNome.Text                   = plr.Name
    lblNome.TextColor3             = cor
    lblNome.Font                   = Enum.Font.GothamBold
    lblNome.TextSize               = 12
    lblNome.TextXAlignment         = Enum.TextXAlignment.Center
    lblNome.Parent                 = bg

    local baraBg = Instance.new("Frame")
    baraBg.Size             = UDim2.new(1,-8,0,4)
    baraBg.Position         = UDim2.new(0,4,0,24)
    baraBg.BackgroundColor3 = Color3.fromRGB(30,30,30)
    baraBg.BorderSizePixel  = 0
    baraBg.Parent           = bg
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(1,0)
    c1.Parent       = baraBg

    local baraFill = Instance.new("Frame")
    baraFill.Size             = UDim2.new(1,0,1,0)
    baraFill.BackgroundColor3 = Color3.fromRGB(60,220,100)
    baraFill.BorderSizePixel  = 0
    baraFill.Parent           = baraBg
    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(1,0)
    c2.Parent       = baraFill

    local lblInfo = Instance.new("TextLabel")
    lblInfo.Size                   = UDim2.new(1,-8,0,12)
    lblInfo.Position               = UDim2.new(0,4,0,32)
    lblInfo.BackgroundTransparency = 1
    lblInfo.Text                   = "HP: ? | Dist: ?"
    lblInfo.TextColor3             = Color3.fromRGB(200,200,200)
    lblInfo.Font                   = Enum.Font.Gotham
    lblInfo.TextSize               = 10
    lblInfo.TextXAlignment         = Enum.TextXAlignment.Center
    lblInfo.Parent                 = bg

    local line        = Drawing.new("Line")
    line.Visible      = false
    line.Thickness    = Estado.espTracerGross
    line.Color        = cor
    line.Transparency = Estado.espTracerTransp

    _espDados[plr.Name] = {
        plr      = plr,
        hl       = hl,
        gui      = gui,
        line     = line,
        stroke   = stroke,
        baraFill = baraFill,
        lblNome  = lblNome,
        lblInfo  = lblInfo,
    }
end

local function LimparTodoESP()
    for nome in pairs(_espDados) do RemoverEntradaESP(nome) end
end

-- ══════════════════════════════════════════════
--  ESP — MOTOR
-- ══════════════════════════════════════════════
local function IniciarESP()
    LimparConexoes(_consESP)
    LimparTodoESP()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            CriarEntradaESP(plr)
        end
    end

    table.insert(_consESP, Players.PlayerAdded:Connect(function(plr)
        table.insert(_consESP, plr.CharacterAdded:Connect(function()
            task.wait(0.6)
            if Estado.hubFechado or not Estado.esp then return end
            CriarEntradaESP(plr)
        end))
        task.wait(0.6)
        if Estado.hubFechado or not Estado.esp then return end
        if plr.Character then CriarEntradaESP(plr) end
    end))

    table.insert(_consESP, Players.PlayerRemoving:Connect(function(plr)
        RemoverEntradaESP(plr.Name)
    end))

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(_consESP, plr.CharacterAdded:Connect(function()
                task.wait(0.6)
                if Estado.hubFechado or not Estado.esp then return end
                CriarEntradaESP(plr)
            end))
            table.insert(_consESP, plr.CharacterRemoving:Connect(function()
                RemoverEntradaESP(plr.Name)
            end))
        end
    end

    table.insert(_consESP, RunService.RenderStepped:Connect(function()
        if Estado.hubFechado then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if plr.Character and not _espDados[plr.Name] then
                CriarEntradaESP(plr)
            elseif not plr.Character and _espDados[plr.Name] then
                RemoverEntradaESP(plr.Name)
            end
        end

        local myHRP = GetHRP()
        local tracerOrigem
        if myHRP then
            local sp, onSc, depth = WorldToViewport(myHRP.Position - Vector3.new(0,2,0))
            tracerOrigem = (onSc and depth > 0) and sp or nil
        end
        if not tracerOrigem then
            tracerOrigem = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        end

        for _, d in pairs(_espDados) do
            local plr = d.plr
            if not plr or not plr.Character then continue end
            local char = plr.Character
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then continue end

            if d.hl  and d.hl.Parent  then d.hl.Enabled  = Estado.esp end
            if d.gui and d.gui.Parent then d.gui.Enabled = Estado.esp end

            if not Estado.esp then
                if d.line then d.line.Visible = false end
                continue
            end

            local dist  = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
            local hp    = math.floor(hum.Health)
            local maxHp = math.floor(hum.MaxHealth)
            local pct   = maxHp > 0 and (hp / maxHp) or 0

            local barCor = pct > 0.6 and Color3.fromRGB(60,220,100)
                        or pct > 0.3 and Color3.fromRGB(255,190,40)
                        or              Color3.fromRGB(220,55,55)

            if d.baraFill and d.baraFill.Parent then
                d.baraFill.Size             = UDim2.new(math.clamp(pct,0,1),0,1,0)
                d.baraFill.BackgroundColor3 = barCor
            end
            if d.lblInfo and d.lblInfo.Parent then
                d.lblInfo.Text = "HP "..hp.."/"..maxHp.."  |  "..dist.."m"
            end

            if d.line then
                local sp, onScreen, depth = WorldToViewport(hrp.Position - Vector3.new(0,2.5,0))
                if Estado.espTracers and onScreen and depth > 0 then
                    d.line.From         = tracerOrigem
                    d.line.To           = sp
                    d.line.Color        = Estado.corESP
                    d.line.Thickness    = Estado.espTracerGross
                    d.line.Transparency = Estado.espTracerTransp
                    d.line.Visible      = true
                else
                    d.line.Visible = false
                end
            end
        end
    end))
end

local function PararESP()
    LimparConexoes(_consESP)
    LimparTodoESP()
end

-- ══════════════════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════════════════
local _noclipConn

local function IniciarNoclip()
    _noclipConn = RunService.Stepped:Connect(function()
        local char = GetChar()
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end

local function PararNoclip()
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn = nil end
    local char = GetChar()
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = true end
    end
end

-- ══════════════════════════════════════════════
--  FLY
-- ══════════════════════════════════════════════
local _flyHB

local function PararFly()
    if _flyHB then _flyHB:Disconnect(); _flyHB = nil end
    local char = GetChar()
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false; hum.AutoRotate = true end
    end
    Estado.fly = false
end

local function IniciarFly()
    PararFly()
    Estado.fly = true
    local char = GetChar()
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then Estado.fly = false; return end

    hum.AutoRotate = false

    local bv    = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.P        = 9e4
    bv.Parent   = hrp

    local bg     = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
    bg.P         = 9e4
    bg.D         = 1e3
    bg.CFrame    = CFrame.new(Vector3.zero, Camera.CFrame.LookVector)
    bg.Parent    = hrp

    _flyHB = RunService.Heartbeat:Connect(function()
        if not Estado.fly then PararFly(); return end
        local hrp2 = GetHRP()
        if not hrp2 or not bv.Parent or not bg.Parent then PararFly(); return end

        local cam = Camera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector      end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector      end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector     end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector     end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end

        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * Estado.voarVel
        bg.CFrame   = CFrame.new(Vector3.zero, Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z))
    end)
end

-- ══════════════════════════════════════════════
--  AUTO FARM ORBS
-- ══════════════════════════════════════════════
local _orbEvent

local function GetOrbEvent()
    if _orbEvent then return _orbEvent end
    local ok, ev = pcall(function()
        return ReplicatedStorage:WaitForChild("rEvents",5):WaitForChild("orbEvent",5)
    end)
    if ok and ev then _orbEvent = ev end
    return _orbEvent
end

local function ColetarOrbs()
    local ev = GetOrbEvent()
    if not ev then return end
    pcall(function() ev:FireServer("collectOrb","Blue Orb","City")   end)
    pcall(function() ev:FireServer("collectOrb","Yellow Orb","City") end)
    pcall(function() ev:FireServer("collectOrb","Red Orb","City")    end)
end

local function ColetarDiamond()
    local ev = GetOrbEvent()
    if not ev then return end
    pcall(function() ev:FireServer("collectOrb","Gem","City") end)
end

local function IniciarAutofarm()
    LimparConexoes(_consFarm)
    table.insert(_consFarm, RunService.Heartbeat:Connect(function()
        if Estado.hubFechado then return end
        if Estado.autofarm        then ColetarOrbs()    end
        if Estado.autofarmdiamond then ColetarDiamond() end
    end))
end

local function PararAutofarm()
    Estado.autofarm        = false
    Estado.autofarmdiamond = false
    LimparConexoes(_consFarm)
end

-- ══════════════════════════════════════════════
--  AUTO FARM HOOPS
-- ══════════════════════════════════════════════
local _hoopBackup = {}
local _hoopConn
local _hoopTick   = 0

local function SalvarHoopsOriginal()
    local hoopsFolder = workspace:FindFirstChild("Hoops")
    if not hoopsFolder then return end
    for _, obj in ipairs(hoopsFolder:GetChildren()) do
        if obj:IsA("MeshPart") and obj.Name == "Hoop" then
            if not _hoopBackup[obj] then
                _hoopBackup[obj] = obj.CFrame
            end
        end
    end
end

local function PuxarHoops()
    local hoopsFolder = workspace:FindFirstChild("Hoops")
    if not hoopsFolder then return end
    local myHRP = GetHRP()
    if not myHRP then return end
    _hoopTick = _hoopTick + 1
    local offsetY = math.sin(_hoopTick * 0.8) * 4
    for _, obj in ipairs(hoopsFolder:GetChildren()) do
        if obj:IsA("MeshPart") and obj.Name == "Hoop" then
            pcall(function() obj.CFrame = myHRP.CFrame * CFrame.new(0, offsetY, 0) end)
        end
    end
end

local function RestaurarHoops()
    for hoop, cf in pairs(_hoopBackup) do
        if hoop and hoop.Parent then
            pcall(function() hoop.CFrame = cf end)
        end
    end
end

local function IniciarHoops()
    if _hoopConn then _hoopConn:Disconnect(); _hoopConn = nil end
    SalvarHoopsOriginal()
    _hoopConn = RunService.Heartbeat:Connect(function()
        if Estado.hubFechado or not Estado.autohoops then return end
        PuxarHoops()
    end)
end

local function PararHoops()
    Estado.autohoops = false
    if _hoopConn then _hoopConn:Disconnect(); _hoopConn = nil end
    RestaurarHoops()
end

local function ResetarBackupHoops()
    table.clear(_hoopBackup)
end

-- ══════════════════════════════════════════════
--  AUTO REBIRTH
-- ══════════════════════════════════════════════
local _rebirthConn
local _rebirthEvent

local function GetRebirthEvent()
    if _rebirthEvent then return _rebirthEvent end
    local ok, ev = pcall(function()
        return ReplicatedStorage:WaitForChild("rEvents",5):WaitForChild("rebirthEvent",5)
    end)
    if ok and ev then _rebirthEvent = ev end
    return _rebirthEvent
end

local function IniciarAutoRebirth()
    if _rebirthConn then _rebirthConn:Disconnect(); _rebirthConn = nil end
    _rebirthConn = RunService.Heartbeat:Connect(function()
        if Estado.hubFechado or not Estado.autorebirth then return end
        local levelAtual = GetLevelAtual()
        local needed     = GetNeededLevel()
        if needed > 0 and levelAtual >= needed then
            local ev = GetRebirthEvent()
            if ev then pcall(function() ev:FireServer("rebirthRequest") end) end
        end
    end)
end

local function PararAutoRebirth()
    Estado.autorebirth = false
    if _rebirthConn then _rebirthConn:Disconnect(); _rebirthConn = nil end
end

-- ══════════════════════════════════════════════
--  RESPAWN
-- ══════════════════════════════════════════════
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Estado.fly    then IniciarFly()                   end
    if Estado.noclip then PararNoclip(); IniciarNoclip() end
    local hum = GetHum()
    if hum then hum.WalkSpeed = Estado.walkspeed end
end)

-- ══════════════════════════════════════════════
--  MONTA O HUB
-- ══════════════════════════════════════════════
local url  = "https://raw.githubusercontent.com/UnityDvloper/Codes/refs/heads/main/Hub"
local site = loadstring(game:HttpGet(url, true))()

local hub = site.novo("ESP Universal", "Escuro", "Lento")

IniciarAutofarm()
IniciarHoops()
IniciarSessao()

-- ╔══════════════════════════════════════════╗
-- ║  ABA: ESP                                ║
-- ╚══════════════════════════════════════════╝
local abaESP = hub:CriarAba("ESP", "👁️")

abaESP:CriarSecao("Visibilidade")
abaESP:CriarToggle("ESP Players", Estado.esp, function(v)
    Estado.esp = v
    if v then IniciarESP(); hub:Notificar("ESP","Ativado!","sucesso",2)
    else PararESP(); hub:Notificar("ESP","Desativado","info",2) end
end)

abaESP:CriarSecao("Tracers")
abaESP:CriarToggle("Mostrar Tracers", Estado.espTracers, function(v)
    Estado.espTracers = v
    if not v then
        for _, d in pairs(_espDados) do
            if d.line then d.line.Visible = false end
        end
    end
end)
abaESP:CriarSlider("Grossura", 1, 20, Estado.espTracerGross, function(v)
    Estado.espTracerGross = v
    for _, d in pairs(_espDados) do if d.line then d.line.Thickness = v end end
end)
abaESP:CriarSlider("Transparencia (0=solido)", 0, 90, math.floor(Estado.espTracerTransp*100), function(v)
    Estado.espTracerTransp = v/100
    for _, d in pairs(_espDados) do if d.line then d.line.Transparency = Estado.espTracerTransp end end
end)

abaESP:CriarSecao("Cor")
abaESP:CriarColorPicker("Cor do ESP", Estado.corESP, function(cor)
    Estado.corESP = cor
    for _, d in pairs(_espDados) do
        if d.hl     and d.hl.Parent      then d.hl.FillColor        = cor end
        if d.stroke and d.stroke.Parent  then d.stroke.Color        = cor end
        if d.line                         then d.line.Color          = cor end
        if d.lblNome and d.lblNome.Parent then d.lblNome.TextColor3 = cor end
    end
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: JOGADOR                            ║
-- ╚══════════════════════════════════════════╝
local abaJogador = hub:CriarAba("Jogador", "🧍")

abaJogador:CriarSecao("Movimento")
abaJogador:CriarToggle("Noclip (atravessar paredes)", Estado.noclip, function(v)
    Estado.noclip = v
    if v then IniciarNoclip(); hub:Notificar("Noclip","Ativado!","sucesso",2)
    else PararNoclip(); hub:Notificar("Noclip","Desativado","info",2) end
end)
abaJogador:CriarSlider("Velocidade de Andar", 8, 1000, Estado.walkspeed, function(v)
    Estado.walkspeed = v
    local hum = GetHum()
    if hum then hum.WalkSpeed = v end
end)

abaJogador:CriarSecao("Voar")
abaJogador:CriarTexto("W/A/S/D = direção da câmera\nSpace = subir  |  Shift = descer")
abaJogador:CriarToggle("Voar", Estado.fly, function(v)
    if v then IniciarFly(); hub:Notificar("Voar","Ativado!","sucesso",2)
    else PararFly(); hub:Notificar("Voar","Desativado","info",2) end
end)
abaJogador:CriarSlider("Velocidade de Voo", 10, 1000, Estado.voarVel, function(v)
    Estado.voarVel = v
end)

abaJogador:CriarSecao("Teleporte")
abaJogador:CriarTexto("Selecione um jogador e clique em Teleportar.")

local dropTP = abaJogador:CriarDropdown("Jogador", GetListaJogadores(), function(_) end)

abaJogador:CriarBotao("🚀 Teleportar", function()
    local alvo = dropTP:Obter()
    if alvo == "Nenhum jogador" then
        hub:Notificar("Teleporte","Nenhum jogador disponível","aviso",2)
        return
    end
    local ok = TeleportarPara(alvo)
    if ok then
        hub:Notificar("Teleporte","Teleportado para "..alvo,"sucesso",2)
    else
        hub:Notificar("Teleporte",alvo.." não encontrado","erro",2)
    end
end)

-- atualiza dropdown quando jogadores entram/saem
Players.PlayerAdded:Connect(function()
    task.wait(1)
    if Estado.hubFechado then return end
    dropTP:AtualizarOpcoes(GetListaJogadores())
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    if Estado.hubFechado then return end
    dropTP:AtualizarOpcoes(GetListaJogadores())
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: FARM                               ║
-- ╚══════════════════════════════════════════╝
local abaFarm = hub:CriarAba("Farm", "🌀")

abaFarm:CriarSecao("Auto Farm Orbs")
abaFarm:CriarTexto("Coleta Blue Orb, Yellow Orb e Red Orb automaticamente.")
abaFarm:CriarToggle("Auto Farm Orbs", Estado.autofarm, function(v)
    Estado.autofarm = v
    if v then hub:Notificar("Auto Farm","Orbs ativado!","sucesso",2)
    else hub:Notificar("Auto Farm","Orbs desativado","info",2) end
end)

abaFarm:CriarSecao("Auto Farm Diamonds")
abaFarm:CriarTexto("Coleta Gems automaticamente.")
abaFarm:CriarToggle("Auto Farm Diamonds", Estado.autofarmdiamond, function(v)
    Estado.autofarmdiamond = v
    if v then hub:Notificar("Auto Farm","Diamonds ativado!","sucesso",2)
    else hub:Notificar("Auto Farm","Diamonds desativado","info",2) end
end)

abaFarm:CriarSecao("Auto Farm Hoops")
abaFarm:CriarTexto("Puxa todos os Hoops até você.\nAo desativar os Hoops voltam ao lugar.")
abaFarm:CriarToggle("Auto Farm Hoops", Estado.autohoops, function(v)
    Estado.autohoops = v
    if v then IniciarHoops(); hub:Notificar("Auto Farm","Hoops ativado!","sucesso",2)
    else PararHoops(); hub:Notificar("Auto Farm","Hoops desativado - posições restauradas","info",2.5) end
end)

abaFarm:CriarSecao("Auto Rebirth")
abaFarm:CriarTexto("Faz rebirth automaticamente quando\natingir o level necessário.")
abaFarm:CriarToggle("Auto Rebirth", Estado.autorebirth, function(v)
    Estado.autorebirth = v
    if v then IniciarAutoRebirth(); hub:Notificar("Auto Rebirth","Ativado!","sucesso",2)
    else PararAutoRebirth(); hub:Notificar("Auto Rebirth","Desativado","info",2) end
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: STATS                              ║
-- ╚══════════════════════════════════════════╝
local abaStats = hub:CriarAba("Stats", "📊")

abaStats:CriarSecao("Seus Stats Atuais")
local lblStatsAtual = abaStats:CriarTexto("Carregando...")

abaStats:CriarSecao("Farmado nesta Sessão")
local lblStatsSessao = abaStats:CriarTexto("Aguardando dados...")

task.spawn(function()
    while not Estado.hubFechado do
        task.wait(0.5)

        local levelAtual = GetLevelAtual()
        local needed     = GetNeededLevel()
        local gems       = GetGems()
        local hoops      = GetHoops()
        local steps      = GetSteps()
        local rebirths   = GetRebirths()

        if levelAtual > Sessao.levelAnterior then
            Sessao.levelAcumulado = Sessao.levelAcumulado + (levelAtual - Sessao.levelAnterior)
        end
        Sessao.levelAnterior = levelAtual

        local txtAtual =
            "🏆 Level: "                .. levelAtual ..
            "\n🔄 Rebirth necessário: " .. needed     .. " Levels" ..
            "\n💎 Gems: "              .. gems        ..
            "\n🏀 Hoops: "             .. hoops       ..
            "\n👟 Steps: "             .. steps       ..
            "\n✨ Rebirths: "          .. rebirths

        pcall(function() lblStatsAtual:Definir(txtAtual) end)

        local stepsF    = math.max(0, steps    - Sessao.stepsInicio)
        local hoopsF    = math.max(0, hoops    - Sessao.hoopsInicio)
        local gemsF     = math.max(0, gems     - Sessao.gemsInicio)
        local rebirthsF = math.max(0, rebirths - Sessao.rebirthsIni)

        local txtSessao =
            "📈 Levels farmados: "   .. Sessao.levelAcumulado ..
            "\n👟 Steps farmados: "  .. stepsF                ..
            "\n🏀 Hoops farmados: "  .. hoopsF                ..
            "\n💎 Gems farmadas: "   .. gemsF                 ..
            "\n✨ Rebirths feitos: " .. rebirthsF

        pcall(function() lblStatsSessao:Definir(txtSessao) end)
    end
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: CONFIG                             ║
-- ╚══════════════════════════════════════════╝
local abaConfig = hub:CriarAba("Config", "⚙️")
abaConfig:CriarSecao("Aparência")
hub:CriarDropdownTemas(abaConfig)

hub:AoFechar(function()
    Estado.hubFechado = true
    PararESP()
    PararFly()
    PararNoclip()
    PararAutofarm()
    PararHoops()
    PararAutoRebirth()
    ResetarBackupHoops()
end)
