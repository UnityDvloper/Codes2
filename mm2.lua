local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
    hubFechado        = false,

    corMurder         = Color3.fromRGB(220, 50,  50),
    corXerife         = Color3.fromRGB(50,  130, 255),
    corInocente       = Color3.fromRGB(50,  220, 100),

    noclip            = false,
    fly               = false,
    walkspeed         = 16,
    voarVel           = 50,
}

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
    gui.Size        = UDim2.new(0, 130, 0, 60)
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
    if papel == d.papel then return end -- nada mudou
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
--  ESP — MOTOR
-- ══════════════════════════════════════════════
local _estavaNaPartida = false

local function IniciarESP()
    LimparConexoes(_consESP)
    LimparTodoESP()

    -- scan inicial
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            CriarEntradaESP(plr)
        end
    end

    -- novo jogador entra no servidor
    table.insert(_consESP, Players.PlayerAdded:Connect(function(plr)
        table.insert(_consESP, plr.CharacterAdded:Connect(function()
            task.wait(0.6)
            if Estado.hubFechado or not Estado.esp then return end
            CriarEntradaESP(plr)
        end))
    end))

    -- jogador sai
    table.insert(_consESP, Players.PlayerRemoving:Connect(function(plr)
        RemoverEntradaESP(plr.Name)
    end))

    -- personagem de jogadores já no servidor respawna
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(_consESP, plr.CharacterAdded:Connect(function()
                task.wait(0.6)
                if Estado.hubFechado or not Estado.esp then return end
                CriarEntradaESP(plr)
            end))
            -- personagem removido = limpa entrada
            table.insert(_consESP, plr.CharacterRemoving:Connect(function()
                RemoverEntradaESP(plr.Name)
            end))
        end
    end

    -- loop de render
    table.insert(_consESP, RunService.RenderStepped:Connect(function()
        if Estado.hubFechado then return end

        local naPartida = PartidaRodando()

        if naPartida and not _estavaNaPartida then
            _estavaNaPartida = true
        elseif not naPartida and _estavaNaPartida then
            _estavaNaPartida = false
            ForcarTodosInocente()
        end

        -- verifica se algum jogador entrou/saiu e não tem entrada ainda
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LocalPlayer then continue end
            if plr.Character and not _espDados[plr.Name] then
                CriarEntradaESP(plr)
            elseif not plr.Character and _espDados[plr.Name] then
                RemoverEntradaESP(plr.Name)
            end
        end

        -- atualiza papel só se a partida estiver rodando
        if naPartida then
            for _, d in pairs(_espDados) do
                AtualizarPapelEntrada(d)
            end
        end

        -- origem do tracer = pé do personagem local na tela
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

            -- ativa/desativa highlight e billboard
            if d.hl  and d.hl.Parent  then d.hl.Enabled  = Estado.esp end
            if d.gui and d.gui.Parent then d.gui.Enabled = Estado.esp end

            if not Estado.esp then
                if d.line then d.line.Visible = false end
                continue
            end

            -- HP e distância
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

            -- tracer — só quando o jogador está na tela
            if d.line then
                if Estado.espTracers then
                    local sp, onScreen, depth = WorldToViewport(hrp.Position)
                    if onScreen and depth > 0 then
                        -- destino = ponto do jogador na tela (pés)
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
--  FLY — estilo Infinite Yield
-- ══════════════════════════════════════════════
local _flyHB

local function PararFly()
    if _flyHB then _flyHB:Disconnect(); _flyHB = nil end

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

    _flyHB = RunService.Heartbeat:Connect(function()
        if not Estado.fly then PararFly(); return end

        local char2 = GetChar()
        local hrp2  = char2 and char2:FindFirstChild("HumanoidRootPart")
        if not hrp2 or not bv.Parent or not bg.Parent then
            PararFly(); return
        end

        local cam = Camera.CFrame
        local dir = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            dir = dir + cam.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            dir = dir - cam.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            dir = dir - cam.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            dir = dir + cam.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            dir = dir + Vector3.new(0,1,0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            dir = dir - Vector3.new(0,1,0)
        end

        if dir.Magnitude > 0 then dir = dir.Unit end
        bv.Velocity = dir * Estado.voarVel

        -- mantém personagem vertical, roda só no Y
        bg.CFrame = CFrame.new(
            Vector3.zero,
            Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
        )
    end)
end

-- reaplica ao respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Estado.fly   then IniciarFly()   end
    if Estado.noclip then
        PararNoclip(); IniciarNoclip()
    end
    local hum = GetHum()
    if hum then hum.WalkSpeed = Estado.walkspeed end
end)

-- ══════════════════════════════════════════════
--  MONTA O HUB
-- ══════════════════════════════════════════════
local site = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/UnityDvloper/Codes/refs/heads/main/Hub",
    true
))()

local hub = site.novo("Murder ESP", "Rubi", "Lento")

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

abaJogador:CriarSecao("Voar")

abaJogador:CriarTexto("W/A/S/D = direção da câmera\nSpace = subir  |  Shift = descer")

abaJogador:CriarToggle("Voar", Estado.fly, function(v)
    if v then
        IniciarFly()
        hub:Notificar("Voar", "Ativado!", "sucesso", 2)
    else
        PararFly()
        hub:Notificar("Voar", "Desativado", "info", 2)
    end
end)

abaJogador:CriarSlider("Velocidade de Voo", 10, 350, Estado.voarVel, function(v)
    Estado.voarVel = v
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
end)
