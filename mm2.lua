local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

-- ══════════════════════════════════════════════
--  ESTADO
-- ══════════════════════════════════════════════
local Estado = {
    esp               = false,
    espTracers        = true,
    espTracerGross    = 4,
    espTracerTransp   = 0.1,
    espMostrarArmas   = true,  -- NOVO: ícone de arma no ESP
    espMostrarDist    = true,
    hubFechado        = false,

    corMurder         = Color3.fromRGB(220, 50,  50),
    corXerife         = Color3.fromRGB(50,  130, 255),
    corInocente       = Color3.fromRGB(50,  220, 100),

    noclip            = false,
    fly               = false,
    walkspeed         = 16,
    jumppower         = 50,
    voarVel           = 50,

    -- NOVO
    antiAfk           = false,
    coletarMoedas     = false,
    raioMoeda         = 20,
    tpArma            = false,
    cameraLivre       = false,
    godMode           = false,  -- apenas local (não bloqueia dano real, só visual)
    mostrarGun        = true,   -- mostrar posição da gun no mapa via ESP
}

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local _consESP  = {}
local _espDados = {}

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

-- ══════════════════════════════════════════════
--  DETECÇÃO DE PARTIDA
-- ══════════════════════════════════════════════
local function PartidaRodando()
    local ok, res = pcall(function()
        local part = workspace:FindFirstChild("RoundTimerPart")
        if not part then return false end
        local gui = part:FindFirstChild("SurfaceGui")
        if not gui then return false end
        local lbl = gui:FindFirstChild("Timer")
        if not lbl then return false end
        return lbl.Text ~= "1s" and lbl.Text ~= ""
    end)
    return ok and res
end

-- ══════════════════════════════════════════════
--  DETECÇÃO DE PAPEL
-- ══════════════════════════════════════════════
local function DetectarPapel(plr)
    local backpack     = plr:FindFirstChild("Backpack")
    local char         = plr.Character
    local temKnifeBack = backpack and backpack:FindFirstChild("Knife") ~= nil
    local temGunBack   = backpack and backpack:FindFirstChild("Gun")   ~= nil
    local temKnifeChar = char     and char:FindFirstChild("Knife")     ~= nil
    local temGunChar   = char     and char:FindFirstChild("Gun")       ~= nil
    if temKnifeBack or temKnifeChar then return "murder"  end
    if temGunBack   or temGunChar   then return "xerife"  end
    return "inocente"
end

local function CorDoPapel(papel)
    if papel == "murder" then return Estado.corMurder end
    if papel == "xerife" then return Estado.corXerife end
    return Estado.corInocente
end

local function LabelDoPapel(papel)
    if papel == "murder" then return "🔪 MURDER" end
    if papel == "xerife" then return "🔫 XERIFE" end
    return "😇 INOCENTE"
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

    local papel = DetectarPapel(plr)
    local cor   = CorDoPapel(papel)

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.FillColor           = cor
    hl.OutlineColor        = Color3.new(1,1,1)
    hl.FillTransparency    = 0.45
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = char
    hl.Parent              = char

    -- BillboardGui
    local gui = Instance.new("BillboardGui")
    gui.AlwaysOnTop = true
    gui.Size        = UDim2.new(0, 140, 0, 72)
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

    local lblPapel = Instance.new("TextLabel")
    lblPapel.Size                   = UDim2.new(1,-8,0,14)
    lblPapel.Position               = UDim2.new(0,4,0,2)
    lblPapel.BackgroundTransparency = 1
    lblPapel.Text                   = LabelDoPapel(papel)
    lblPapel.TextColor3             = cor
    lblPapel.Font                   = Enum.Font.GothamBold
    lblPapel.TextSize               = 10
    lblPapel.TextXAlignment         = Enum.TextXAlignment.Center
    lblPapel.Parent                 = bg

    local lblNome = Instance.new("TextLabel")
    lblNome.Size                    = UDim2.new(1,-8,0,14)
    lblNome.Position                = UDim2.new(0,4,0,16)
    lblNome.BackgroundTransparency  = 1
    lblNome.Text                    = plr.Name
    lblNome.TextColor3              = Color3.new(1,1,1)
    lblNome.Font                    = Enum.Font.GothamBold
    lblNome.TextSize                = 11
    lblNome.TextXAlignment          = Enum.TextXAlignment.Center
    lblNome.Parent                  = bg

    local baraBg = Instance.new("Frame")
    baraBg.Size             = UDim2.new(1,-8,0,4)
    baraBg.Position         = UDim2.new(0,4,0,33)
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
    lblInfo.Size                    = UDim2.new(1,-8,0,12)
    lblInfo.Position                = UDim2.new(0,4,0,40)
    lblInfo.BackgroundTransparency  = 1
    lblInfo.Text                    = "HP: ? | Dist: ?"
    lblInfo.TextColor3              = Color3.fromRGB(200,200,200)
    lblInfo.Font                    = Enum.Font.Gotham
    lblInfo.TextSize                = 10
    lblInfo.TextXAlignment          = Enum.TextXAlignment.Center
    lblInfo.Parent                  = bg

    -- NOVO: label de arma
    local lblArma = Instance.new("TextLabel")
    lblArma.Size                    = UDim2.new(1,-8,0,12)
    lblArma.Position                = UDim2.new(0,4,0,54)
    lblArma.BackgroundTransparency  = 1
    lblArma.Text                    = ""
    lblArma.TextColor3              = Color3.fromRGB(255,220,80)
    lblArma.Font                    = Enum.Font.GothamBold
    lblArma.TextSize                = 10
    lblArma.TextXAlignment          = Enum.TextXAlignment.Center
    lblArma.Parent                  = bg

    -- Drawing line
    local line        = Drawing.new("Line")
    line.Visible      = false
    line.Thickness    = Estado.espTracerGross
    line.Color        = cor
    line.Transparency = Estado.espTracerTransp

    _espDados[plr.Name] = {
        papel    = papel,
        plr      = plr,
        hl       = hl,
        gui      = gui,
        line     = line,
        stroke   = stroke,
        baraFill = baraFill,
        lblNome  = lblNome,
        lblPapel = lblPapel,
        lblInfo  = lblInfo,
        lblArma  = lblArma,
    }
end

local function LimparTodoESP()
    for nome in pairs(_espDados) do
        RemoverEntradaESP(nome)
    end
end

-- ══════════════════════════════════════════════
--  ATUALIZAR PAPEL SEM RECRIAR
-- ══════════════════════════════════════════════
local function AtualizarPapelEntrada(d)
    if not d or not d.plr or not d.plr.Character then return end
    local papel = DetectarPapel(d.plr)
    if papel == d.papel then return end
    local cor = CorDoPapel(papel)
    d.papel = papel
    if d.hl     and d.hl.Parent     then d.hl.FillColor           = cor end
    if d.stroke and d.stroke.Parent then d.stroke.Color           = cor end
    if d.line                        then d.line.Color             = cor end
    if d.lblPapel and d.lblPapel.Parent then
        d.lblPapel.Text       = LabelDoPapel(papel)
        d.lblPapel.TextColor3 = cor
    end
end

local function ForcarTodosInocente()
    for _, d in pairs(_espDados) do
        if d.papel == "inocente" then continue end
        local cor = Estado.corInocente
        d.papel   = "inocente"
        if d.hl     and d.hl.Parent     then d.hl.FillColor           = cor end
        if d.stroke and d.stroke.Parent then d.stroke.Color           = cor end
        if d.line                        then d.line.Color             = cor end
        if d.lblPapel and d.lblPapel.Parent then
            d.lblPapel.Text       = LabelDoPapel("inocente")
            d.lblPapel.TextColor3 = cor
        end
    end
end

-- ══════════════════════════════════════════════
--  BUSCAR GUN NO MAPA (NOVO)
-- ══════════════════════════════════════════════
local _gunHighlight = nil

local function BuscarGunNoMapa()
    -- Remove highlight anterior
    if _gunHighlight and _gunHighlight.Parent then
        _gunHighlight:Destroy()
        _gunHighlight = nil
    end
    if not Estado.mostrarGun then return nil end

    -- Procura Gun solta no workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Gun" and obj:IsA("Tool") and not obj.Parent:IsA("Model") then
            -- Gun solta no mapa
            local hl = Instance.new("Highlight")
            hl.FillColor           = Color3.fromRGB(50,130,255)
            hl.OutlineColor        = Color3.fromRGB(150,200,255)
            hl.FillTransparency    = 0.3
            hl.OutlineTransparency = 0
            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee             = obj
            hl.Parent              = obj
            _gunHighlight          = hl
            return obj
        end
    end
    return nil
end

-- ══════════════════════════════════════════════
--  TELEPORTE PARA ARMA (NOVO)
-- ══════════════════════════════════════════════
local function TeleportarParaArma()
    local hrp = GetHRP()
    if not hrp then return end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Gun" and obj:IsA("Tool") then
            local part = obj:FindFirstChildOfClass("Part") or obj:FindFirstChildOfClass("MeshPart")
            if part then
                hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                return true
            end
        end
    end
    return false
end

-- ══════════════════════════════════════════════
--  TELEPORTE PARA JOGADOR (NOVO)
-- ══════════════════════════════════════════════
local function TeleportarParaJogador(nomePlr)
    local plr = Players:FindFirstChild(nomePlr)
    if not plr then return false end
    local hrpAlvo = GetHRP(plr)
    local hrp = GetHRP()
    if not hrpAlvo or not hrp then return false end
    hrp.CFrame = hrpAlvo.CFrame * CFrame.new(0, 0, -3)
    return true
end

-- ══════════════════════════════════════════════
--  AUTO COLETAR MOEDAS (NOVO)
-- ══════════════════════════════════════════════
local _moedaConn

local function IniciarColetarMoedas()
    if _moedaConn then _moedaConn:Disconnect() end
    _moedaConn = RunService.Heartbeat:Connect(function()
        if not Estado.coletarMoedas then return end
        local hrp = GetHRP()
        if not hrp then return end
        -- Coleta moedas próximas (Gold/Coin no workspace)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj.Name == "Gold" or obj.Name == "Coin" or obj.Name == "CoinDrop")
                and (obj:IsA("BasePart") or obj:IsA("Model")) then
                local pos
                if obj:IsA("BasePart") then
                    pos = obj.Position
                elseif obj:IsA("Model") then
                    local root = obj:FindFirstChildOfClass("Part")
                    if root then pos = root.Position end
                end
                if pos and (hrp.Position - pos).Magnitude <= Estado.raioMoeda then
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
                    task.wait(0.05)
                end
            end
        end
    end)
end

local function PararColetarMoedas()
    if _moedaConn then _moedaConn:Disconnect(); _moedaConn = nil end
end

-- ══════════════════════════════════════════════
--  ANTI-AFK (NOVO)
-- ══════════════════════════════════════════════
local _antiAfkConn

local function IniciarAntiAfk()
    if _antiAfkConn then _antiAfkConn:Disconnect() end
    -- Simula input leve para não ser kickado
    _antiAfkConn = task.spawn(function()
        while Estado.antiAfk do
            -- Rotaciona câmera levemente para simular atividade
            local vp = workspace.CurrentCamera.CFrame
            workspace.CurrentCamera.CFrame = vp * CFrame.Angles(0, 0.001, 0)
            task.wait(60) -- a cada 60s
        end
    end)
end

local function PararAntiAfk()
    Estado.antiAfk = false
    -- a goroutine para sozinha
end

-- ══════════════════════════════════════════════
--  ESP — MOTOR
-- ══════════════════════════════════════════════
local _estavaNaPartida = false

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

        local naPartida = PartidaRodando()

        if naPartida and not _estavaNaPartida then
            _estavaNaPartida = true
            BuscarGunNoMapa()
        elseif not naPartida and _estavaNaPartida then
            _estavaNaPartida = false
            ForcarTodosInocente()
            if _gunHighlight and _gunHighlight.Parent then
                _gunHighlight:Destroy(); _gunHighlight = nil
            end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if plr.Character and not _espDados[plr.Name] then
                CriarEntradaESP(plr)
            elseif not plr.Character and _espDados[plr.Name] then
                RemoverEntradaESP(plr.Name)
            end
        end

        if naPartida then
            for _, d in pairs(_espDados) do
                AtualizarPapelEntrada(d)
            end
        end

        local tracerOrigem
        local myHRP = GetHRP()
        if myHRP then
            local sp, onSc, depth = WorldToViewport(myHRP.Position - Vector3.new(0,2,0))
            if onSc and depth > 0 then
                tracerOrigem = sp
            end
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
                if Estado.espMostrarDist then
                    d.lblInfo.Text = "HP "..hp.."/"..maxHp.."  |  "..dist.."m"
                else
                    d.lblInfo.Text = "HP "..hp.."/"..maxHp
                end
            end

            -- NOVO: mostrar arma no label
            if d.lblArma and d.lblArma.Parent and Estado.espMostrarArmas then
                local papel = d.papel
                if papel == "murder" then
                    d.lblArma.Text = "🔪 tem a faca"
                    d.lblArma.TextColor3 = Color3.fromRGB(255,100,100)
                elseif papel == "xerife" then
                    d.lblArma.Text = "🔫 tem a gun"
                    d.lblArma.TextColor3 = Color3.fromRGB(100,180,255)
                else
                    d.lblArma.Text = ""
                end
            elseif d.lblArma and d.lblArma.Parent then
                d.lblArma.Text = ""
            end

            if d.line then
                if Estado.espTracers then
                    local sp, onScreen, depth = WorldToViewport(hrp.Position)
                    if onScreen and depth > 0 then
                        local spPes = WorldToViewport(hrp.Position - Vector3.new(0,2.5,0))
                        d.line.From        = tracerOrigem
                        d.line.To          = spPes
                        d.line.Color       = CorDoPapel(d.papel)
                        d.line.Thickness   = Estado.espTracerGross
                        d.line.Transparency = Estado.espTracerTransp
                        d.line.Visible     = true
                    else
                        d.line.Visible = false
                    end
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
    _estavaNaPartida = false
    if _gunHighlight and _gunHighlight.Parent then
        _gunHighlight:Destroy(); _gunHighlight = nil
    end
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
--  FLY — MOBILE JOYSTICK (MELHORADO)
-- ══════════════════════════════════════════════
local _flyHB
local _flyJoystick = nil  -- GUI do joystick mobile

local function RemoverJoystickMobile()
    if _flyJoystick and _flyJoystick.Parent then
        _flyJoystick:Destroy()
    end
    _flyJoystick = nil
end

local _joyDir = Vector3.zero  -- direção atual do joystick mobile
local _joySubir = false
local _joyDescer = false

local function CriarJoystickMobile()
    RemoverJoystickMobile()
    if not IS_MOBILE then return end

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local joyGui = Instance.new("ScreenGui")
    joyGui.Name = "FlyJoystick"
    joyGui.ResetOnSpawn = false
    joyGui.IgnoreGuiInset = true
    joyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    joyGui.Parent = playerGui
    _flyJoystick = joyGui

    local JOY_SIZE = 120
    local JOY_BALL = 48
    local JOY_PAD = 16

    -- Joystick base (movimento WASD) — canto inferior esquerdo
    local joyBase = Instance.new("Frame")
    joyBase.Name = "JoyBase"
    joyBase.Size = UDim2.new(0, JOY_SIZE, 0, JOY_SIZE)
    joyBase.Position = UDim2.new(0, JOY_PAD, 1, -(JOY_SIZE + JOY_PAD + 80))
    joyBase.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    joyBase.BackgroundTransparency = 0.35
    joyBase.BorderSizePixel = 0
    joyBase.ZIndex = 50
    joyBase.Parent = joyGui
    Instance.new("UICorner", joyBase).CornerRadius = UDim.new(1, 0)
    local joyStroke = Instance.new("UIStroke", joyBase)
    joyStroke.Color = Color3.fromRGB(50, 130, 255)
    joyStroke.Thickness = 2
    joyStroke.Transparency = 0.3

    -- Cruz direcional decorativa
    for _, d2 in ipairs({"↑","↓","←","→"}) do
        local posMap = {
            ["↑"] = UDim2.new(0.5,-8,0,4),
            ["↓"] = UDim2.new(0.5,-8,1,-20),
            ["←"] = UDim2.new(0,4,0.5,-8),
            ["→"] = UDim2.new(1,-20,0.5,-8),
        }
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0,16,0,16)
        lbl.Position = posMap[d2]
        lbl.BackgroundTransparency = 1
        lbl.Text = d2
        lbl.TextColor3 = Color3.fromRGB(80,120,180)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.ZIndex = 51
        lbl.Parent = joyBase
    end

    -- Bolinha do joystick
    local joyBall = Instance.new("Frame")
    joyBall.Name = "JoyBall"
    joyBall.Size = UDim2.new(0, JOY_BALL, 0, JOY_BALL)
    joyBall.Position = UDim2.new(0.5, -JOY_BALL/2, 0.5, -JOY_BALL/2)
    joyBall.BackgroundColor3 = Color3.fromRGB(50, 130, 255)
    joyBall.BackgroundTransparency = 0.1
    joyBall.BorderSizePixel = 0
    joyBall.ZIndex = 52
    joyBall.Parent = joyBase
    Instance.new("UICorner", joyBall).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", joyBall).Color = Color3.new(1,1,1)

    -- Ícone no joystick
    local joyIcon = Instance.new("TextLabel")
    joyIcon.Size = UDim2.new(1,0,1,0)
    joyIcon.BackgroundTransparency = 1
    joyIcon.Text = "✈"
    joyIcon.TextColor3 = Color3.new(1,1,1)
    joyIcon.Font = Enum.Font.GothamBold
    joyIcon.TextSize = 20
    joyIcon.ZIndex = 53
    joyIcon.Parent = joyBall

    -- Botões Subir/Descer — canto inferior direito
    local BTN_S = 56
    local btnSubir = Instance.new("TextButton")
    btnSubir.Size = UDim2.new(0, BTN_S, 0, BTN_S)
    btnSubir.Position = UDim2.new(1, -(BTN_S*2 + JOY_PAD*2), 1, -(BTN_S + JOY_PAD + 80))
    btnSubir.BackgroundColor3 = Color3.fromRGB(40, 200, 120)
    btnSubir.BackgroundTransparency = 0.2
    btnSubir.Text = "▲\nSUBIR"
    btnSubir.Font = Enum.Font.GothamBold
    btnSubir.TextSize = 11
    btnSubir.TextColor3 = Color3.new(1,1,1)
    btnSubir.AutoButtonColor = false
    btnSubir.BorderSizePixel = 0
    btnSubir.ZIndex = 50
    btnSubir.Parent = joyGui
    Instance.new("UICorner", btnSubir).CornerRadius = UDim.new(0, 12)
    Instance.new("UIStroke", btnSubir).Color = Color3.fromRGB(60,220,100)

    local btnDescer = Instance.new("TextButton")
    btnDescer.Size = UDim2.new(0, BTN_S, 0, BTN_S)
    btnDescer.Position = UDim2.new(1, -(BTN_S + JOY_PAD), 1, -(BTN_S + JOY_PAD + 80))
    btnDescer.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    btnDescer.BackgroundTransparency = 0.2
    btnDescer.Text = "▼\nDESCER"
    btnDescer.Font = Enum.Font.GothamBold
    btnDescer.TextSize = 11
    btnDescer.TextColor3 = Color3.new(1,1,1)
    btnDescer.AutoButtonColor = false
    btnDescer.BorderSizePixel = 0
    btnDescer.ZIndex = 50
    btnDescer.Parent = joyGui
    Instance.new("UICorner", btnDescer).CornerRadius = UDim.new(0, 12)
    Instance.new("UIStroke", btnDescer).Color = Color3.fromRGB(220,80,80)

    -- Lógica de toque no joystick
    local joyAtivo = false
    local joyTouchId = nil
    local CENTER = Vector2.new(JOY_SIZE/2, JOY_SIZE/2)
    local MAX_DIST = JOY_SIZE/2 - 4

    local function AtualizarJoy(pos)
        local absPos = joyBase.AbsolutePosition
        local rel = Vector2.new(pos.X - absPos.X, pos.Y - absPos.Y) - CENTER
        local dist2 = rel.Magnitude
        local clamped = dist2 > MAX_DIST and (rel.Unit * MAX_DIST) or rel
        joyBall.Position = UDim2.new(
            0, CENTER.X + clamped.X - JOY_BALL/2,
            0, CENTER.Y + clamped.Y - JOY_BALL/2
        )
        if dist2 > 8 then
            local norm = rel.Unit
            _joyDir = Vector3.new(norm.X, 0, norm.Y)
        else
            _joyDir = Vector3.zero
        end
    end

    local function ResetarJoy()
        joyBall.Position = UDim2.new(0.5, -JOY_BALL/2, 0.5, -JOY_BALL/2)
        _joyDir = Vector3.zero
    end

    joyBase.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            joyAtivo = true; joyTouchId = inp
            AtualizarJoy(inp.Position)
        end
    end)
    joyBase.InputChanged:Connect(function(inp)
        if joyAtivo and inp.UserInputType == Enum.UserInputType.Touch then
            AtualizarJoy(inp.Position)
        end
    end)
    joyBase.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then
            joyAtivo = false; joyTouchId = nil
            ResetarJoy()
        end
    end)

    -- Botões subir/descer
    btnSubir.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then _joySubir = true end
    end)
    btnSubir.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then _joySubir = false end
    end)
    btnDescer.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then _joyDescer = true end
    end)
    btnDescer.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch then _joyDescer = false end
    end)

    -- Efeito visual ao tocar botões
    btnSubir.MouseButton1Down:Connect(function()
        TweenService:Create(btnSubir, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    end)
    btnSubir.MouseButton1Up:Connect(function()
        TweenService:Create(btnSubir, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
    end)
    btnDescer.MouseButton1Down:Connect(function()
        TweenService:Create(btnDescer, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    end)
    btnDescer.MouseButton1Up:Connect(function()
        TweenService:Create(btnDescer, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
    end)
end

local function PararFly()
    if _flyHB then _flyHB:Disconnect(); _flyHB = nil end
    RemoverJoystickMobile()
    _joyDir = Vector3.zero; _joySubir = false; _joyDescer = false

    local char = GetChar()
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then
                    v:Destroy()
                end
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate    = true
        end
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

    local bv     = Instance.new("BodyVelocity")
    bv.Velocity  = Vector3.zero
    bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
    bv.P         = 9e4
    bv.Parent    = hrp

    local bg     = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P         = 9e4
    bg.D         = 1e3
    bg.CFrame    = CFrame.new(Vector3.zero, Camera.CFrame.LookVector)
    bg.Parent    = hrp

    -- Cria joystick mobile
    if IS_MOBILE then
        CriarJoystickMobile()
    end

    _flyHB = RunService.Heartbeat:Connect(function()
        if not Estado.fly then PararFly(); return end

        local char2 = GetChar()
        local hrp2  = char2 and char2:FindFirstChild("HumanoidRootPart")
        if not hrp2 or not bv.Parent or not bg.Parent then
            PararFly(); return
        end

        local cam = Camera.CFrame
        local dir = Vector3.zero

        if IS_MOBILE then
            -- Usa joystick
            if _joyDir.Magnitude > 0.1 then
                -- Converte direção do joystick para espaço da câmera
                local look = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z).Unit
                local right = Vector3.new(cam.RightVector.X, 0, cam.RightVector.Z).Unit
                dir = dir + (look * (-_joyDir.Z)) + (right * _joyDir.X)
            end
            if _joySubir  then dir = dir + Vector3.new(0,1,0) end
            if _joyDescer then dir = dir - Vector3.new(0,1,0) end
        else
            -- Teclado (PC)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0,1,0) end
        end

        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * Estado.voarVel

        bg.CFrame = CFrame.new(
            Vector3.zero,
            Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
        )
    end)
end

-- reaplica ao respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Estado.fly    then IniciarFly()   end
    if Estado.noclip then
        PararNoclip(); IniciarNoclip()
    end
    local hum = GetHum()
    if hum then
        hum.WalkSpeed  = Estado.walkspeed
        hum.JumpPower  = Estado.jumppower
    end
end)

-- ══════════════════════════════════════════════
--  CÂMERA LIVRE (NOVO)
-- ══════════════════════════════════════════════
local _camOrigMode

local function IniciarCameraLivre()
    _camOrigMode = Camera.CameraType
    Camera.CameraType = Enum.CameraType.Scriptable
    Estado.cameraLivre = true
end

local function PararCameraLivre()
    Camera.CameraType = _camOrigMode or Enum.CameraType.Custom
    Estado.cameraLivre = false
end

-- ══════════════════════════════════════════════
--  LISTA DE JOGADORES PARA DROPDOWN (HELPER)
-- ══════════════════════════════════════════════
local function GetNomesJogadores()
    local nomes = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(nomes, plr.Name)
        end
    end
    return nomes
end

-- ══════════════════════════════════════════════
--  MONTA O HUB
-- ══════════════════════════════════════════════
local site = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/UnityDvloper/Codes/refs/heads/main/Hub",
    true
))()

local hub = site.novo("Murder ESP+", "Rubi", "Lento")

-- ╔══════════════════════════════════════════╗
-- ║  ABA: ESP                                ║
-- ╚══════════════════════════════════════════╝
local abaESP = hub:CriarAba("ESP", "👁️")

abaESP:CriarSecao("Visibilidade")

abaESP:CriarToggle("ESP Players", Estado.esp, function(v)
    Estado.esp = v
    if v then
        IniciarESP()
        hub:Notificar("ESP", "Ativado!", "sucesso", 2)
    else
        PararESP()
        hub:Notificar("ESP", "Desativado", "info", 2)
    end
end)

abaESP:CriarToggle("Mostrar ícone de arma", Estado.espMostrarArmas, function(v)
    Estado.espMostrarArmas = v
end)

abaESP:CriarToggle("Mostrar distância", Estado.espMostrarDist, function(v)
    Estado.espMostrarDist = v
end)

abaESP:CriarToggle("Highlight Gun no mapa", Estado.mostrarGun, function(v)
    Estado.mostrarGun = v
    if v then
        BuscarGunNoMapa()
    else
        if _gunHighlight and _gunHighlight.Parent then
            _gunHighlight:Destroy(); _gunHighlight = nil
        end
    end
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
    for _, d in pairs(_espDados) do
        if d.line then d.line.Thickness = v end
    end
end)

abaESP:CriarSlider("Transparencia (0=solido)", 0, 90, math.floor(Estado.espTracerTransp * 100), function(v)
    Estado.espTracerTransp = v / 100
    for _, d in pairs(_espDados) do
        if d.line then d.line.Transparency = Estado.espTracerTransp end
    end
end)

abaESP:CriarSecao("Cores")

abaESP:CriarColorPicker("🔪 Murder", Estado.corMurder, function(cor)
    Estado.corMurder = cor
    for _, d in pairs(_espDados) do
        if d.papel == "murder" then
            if d.hl     and d.hl.Parent     then d.hl.FillColor           = cor end
            if d.stroke and d.stroke.Parent then d.stroke.Color           = cor end
            if d.line                        then d.line.Color             = cor end
            if d.lblPapel and d.lblPapel.Parent then d.lblPapel.TextColor3 = cor end
        end
    end
end)

abaESP:CriarColorPicker("🔫 Xerife", Estado.corXerife, function(cor)
    Estado.corXerife = cor
    for _, d in pairs(_espDados) do
        if d.papel == "xerife" then
            if d.hl     and d.hl.Parent     then d.hl.FillColor           = cor end
            if d.stroke and d.stroke.Parent then d.stroke.Color           = cor end
            if d.line                        then d.line.Color             = cor end
            if d.lblPapel and d.lblPapel.Parent then d.lblPapel.TextColor3 = cor end
        end
    end
end)

abaESP:CriarColorPicker("😇 Inocente", Estado.corInocente, function(cor)
    Estado.corInocente = cor
    for _, d in pairs(_espDados) do
        if d.papel == "inocente" then
            if d.hl     and d.hl.Parent     then d.hl.FillColor           = cor end
            if d.stroke and d.stroke.Parent then d.stroke.Color           = cor end
            if d.line                        then d.line.Color             = cor end
            if d.lblPapel and d.lblPapel.Parent then d.lblPapel.TextColor3 = cor end
        end
    end
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: JOGADOR                            ║
-- ╚══════════════════════════════════════════╝
local abaJogador = hub:CriarAba("Jogador", "🧍")

abaJogador:CriarSecao("Movimento")

abaJogador:CriarToggle("Noclip (atravessar paredes)", Estado.noclip, function(v)
    Estado.noclip = v
    if v then
        IniciarNoclip()
        hub:Notificar("Noclip", "Ativado!", "sucesso", 2)
    else
        PararNoclip()
        hub:Notificar("Noclip", "Desativado", "info", 2)
    end
end)

abaJogador:CriarSlider("Velocidade de Andar", 16, 250, Estado.walkspeed, function(v)
    Estado.walkspeed = v
    local hum = GetHum()
    if hum then hum.WalkSpeed = v end
end)

abaJogador:CriarSlider("Força de Pulo", 25, 200, Estado.jumppower, function(v)  -- NOVO
    Estado.jumppower = v
    local hum = GetHum()
    if hum then hum.JumpPower = v end
end)

abaJogador:CriarSecao("Voar")

if IS_MOBILE then
    abaJogador:CriarTexto("📱 Mobile: use o joystick que aparece\nna tela ao ativar o voo!\n▲ Subir  |  ▼ Descer")
else
    abaJogador:CriarTexto("W/A/S/D = direção da câmera\nSpace = subir  |  Shift = descer")
end

abaJogador:CriarToggle("Voar", Estado.fly, function(v)
    if v then
        IniciarFly()
        hub:Notificar("Voar", "Ativado! ".. (IS_MOBILE and "Use o joystick 🕹️" or "WASD para mover"), "sucesso", 3)
    else
        PararFly()
        hub:Notificar("Voar", "Desativado", "info", 2)
    end
end)

abaJogador:CriarSlider("Velocidade de Voo", 10, 350, Estado.voarVel, function(v)
    Estado.voarVel = v
end)

abaJogador:CriarSecao("Utilitários")

abaJogador:CriarToggle("Anti-AFK", Estado.antiAfk, function(v)  -- NOVO
    Estado.antiAfk = v
    if v then
        IniciarAntiAfk()
        hub:Notificar("Anti-AFK", "Ativo — você não será kickado!", "sucesso", 3)
    else
        PararAntiAfk()
        hub:Notificar("Anti-AFK", "Desativado", "info", 2)
    end
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: TELEPORTE (NOVO)                   ║
-- ╚══════════════════════════════════════════╝
local abaTp = hub:CriarAba("Teleporte", "🚀")

abaTp:CriarSecao("Teleportes Rápidos")

abaTp:CriarBotao("📦 Ir para a Arma (Gun)", function()
    local ok = TeleportarParaArma()
    if ok then
        hub:Notificar("Teleporte", "Teleportado para a arma!", "sucesso", 2)
    else
        hub:Notificar("Teleporte", "Nenhuma arma encontrada no mapa", "aviso", 2)
    end
end)

abaTp:CriarSecao("Ir para Jogador")
abaTp:CriarTexto("Selecione um jogador abaixo e clique em Ir!")

local ddJogadores = abaTp:CriarDropdown(
    "Jogador",
    GetNomesJogadores(),
    function(v) end,
    {search = true, placeholder = "Escolha um jogador..."}
)

-- Atualiza lista de jogadores periodicamente
task.spawn(function()
    while task.wait(5) do
        if Estado.hubFechado then break end
        ddJogadores:AtualizarOpcoes(GetNomesJogadores())
    end
end)

abaTp:CriarBotao("🚀 Teleportar para jogador", function()
    local nome = ddJogadores:Obter()
    if not nome or nome == "" then
        hub:Notificar("Teleporte", "Selecione um jogador primeiro!", "aviso", 2)
        return
    end
    local ok = TeleportarParaJogador(nome)
    if ok then
        hub:Notificar("Teleporte", "Teleportado para "..nome, "sucesso", 2)
    else
        hub:Notificar("Teleporte", "Jogador não encontrado", "erro", 2)
    end
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: MOEDAS (NOVO)                      ║
-- ╚══════════════════════════════════════════╝
local abaMoedas = hub:CriarAba("Moedas", "💰")

abaMoedas:CriarSecao("Auto Coletar")

abaMoedas:CriarTexto("Coleta automaticamente moedas/gold\npróximas ao seu personagem.")

abaMoedas:CriarToggle("Auto Coletar Moedas", Estado.coletarMoedas, function(v)
    Estado.coletarMoedas = v
    if v then
        IniciarColetarMoedas()
        hub:Notificar("Moedas", "Auto-coletar ativado!", "sucesso", 2)
    else
        PararColetarMoedas()
        hub:Notificar("Moedas", "Auto-coletar desativado", "info", 2)
    end
end)

abaMoedas:CriarSlider("Raio de Coleta (studs)", 5, 100, Estado.raioMoeda, function(v)
    Estado.raioMoeda = v
end)

abaMoedas:CriarSecao("Moedas Rápidas")

abaMoedas:CriarBotao("💨 Coletar todas agora (TP)", function()
    local hrp = GetHRP()
    if not hrp then return end
    local coletadas = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj.Name == "Gold" or obj.Name == "Coin" or obj.Name == "CoinDrop") and obj:IsA("BasePart") then
            hrp.CFrame = CFrame.new(obj.Position + Vector3.new(0,1,0))
            coletadas = coletadas + 1
            task.wait(0.05)
        end
    end
    hub:Notificar("Moedas", "Coletou "..coletadas.." moedas!", "sucesso", 3)
end)

-- ╔══════════════════════════════════════════╗
-- ║  ABA: CONFIG                             ║
-- ╚══════════════════════════════════════════╝
local abaConfig = hub:CriarAba("Config", "⚙️")
abaConfig:CriarSecao("Aparência")
hub:CriarDropdownTemas(abaConfig)

abaConfig:CriarSecao("Ajuste da Janela")
abaConfig:CriarAjusteTamanho("Largura", "Altura")

abaConfig:CriarSecao("Sobre")
abaConfig:CriarTexto("Murder ESP+ v2.0\nFeito com ❤️ para MM2\n\nESP | Fly Mobile | Teleporte\nAnti-AFK | Auto Moedas")

hub:AoFechar(function()
    Estado.hubFechado = true
    PararESP()
    PararFly()
    PararNoclip()
    PararColetarMoedas()
    PararAntiAfk()
    if _gunHighlight and _gunHighlight.Parent then _gunHighlight:Destroy() end
end)
