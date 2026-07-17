-- 弹反之室：原生 NanoVG 负责游戏画面，UI 组件负责响应式中文 HUD 与宝箱选择。

local UI = require("urhox-libs/UI")
local Config = require "Config"
local Game = require "Game"
local Renderer = require "Renderer"

---@type any
local nvgContext = nil
local game = nil
local physicalWidth = 0
local physicalHeight = 0
local devicePixelRatio = 1.0
local logicalWidth = 0
local logicalHeight = 0
local hudTimer = 0

---@type Widget|nil
local healthLabel = nil
---@type Widget|nil
local roomLabel = nil
---@type Widget|nil
local parryLabel = nil
---@type Widget|nil
local abilityLabel = nil
---@type Widget|nil
local chestPanel = nil
local chestTitleLabels = {}
local chestDescriptionLabels = {}
local chestCards = {}

local function RefreshCanvasMetrics()
    physicalWidth = graphics:GetWidth()
    physicalHeight = graphics:GetHeight()
    devicePixelRatio = graphics:GetDPR()
    logicalWidth = physicalWidth / devicePixelRatio
    logicalHeight = physicalHeight / devicePixelRatio
end

local function ChooseChestOption(index)
    if game ~= nil and Game.SelectUpgrade(game, index) then
        hudTimer = 1.0
    end
end

local function CreateChestCard(index)
    local optionIndex = index
    local title = UI.Label {
        text = "强化名称",
        fontSize = 18,
        fontWeight = "bold",
        textAlign = "center",
        fontColor = { 245, 235, 180, 255 },
    }
    local description = UI.Label {
        text = "强化说明",
        fontSize = 12,
        textAlign = "center",
        fontColor = { 225, 230, 255, 220 },
    }
    local card = UI.Panel {
        flexGrow = 1,
        flexBasis = 0,
        padding = 14,
        gap = 10,
        minHeight = 178,
        backgroundColor = { 35, 30, 62, 246 },
        borderRadius = 10,
        borderWidth = 1,
        borderColor = { 236, 202, 105, 135 },
        alignItems = "center",
        justifyContent = "space-between",
        pointerEvents = "auto",
        children = {
            title,
            description,
            UI.Button {
                text = "选择 [" .. tostring(optionIndex) .. "]",
                width = "100%",
                variant = "primary",
                onClick = function()
                    ChooseChestOption(optionIndex)
                end,
            },
        },
    }

    chestTitleLabels[index] = title
    chestDescriptionLabels[index] = description
    chestCards[index] = card
    return card
end

local function CreateHud()
    healthLabel = UI.Label {
        text = "生命 ●●●",
        fontSize = 21,
        fontColor = { 255, 132, 154, 255 },
    }
    roomLabel = UI.Label {
        text = "尚未开始",
        fontSize = 14,
        fontColor = { 232, 237, 255, 245 },
    }
    parryLabel = UI.Label {
        text = "招架 就绪",
        fontSize = 14,
        fontColor = { 130, 232, 255, 255 },
    }
    abilityLabel = UI.Label {
        text = "暂无强化",
        fontSize = 12,
        textAlign = "right",
        fontColor = { 197, 175, 255, 235 },
    }

    chestPanel = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 7, 7, 18, 205 },
        pointerEvents = "auto",
        children = {
            UI.Panel {
                width = "90%",
                maxWidth = 820,
                padding = 22,
                gap = 16,
                backgroundColor = { 23, 20, 45, 252 },
                borderRadius = 14,
                borderWidth = 2,
                borderColor = { 246, 211, 112, 220 },
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "宝箱开启",
                        fontSize = 28,
                        fontWeight = "bold",
                        fontColor = { 255, 226, 125, 255 },
                    },
                    UI.Label {
                        text = "选择一项强化（按 1 / 2 / 3 也可选择）",
                        fontSize = 13,
                        fontColor = { 220, 226, 255, 220 },
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = 12,
                        children = { CreateChestCard(1), CreateChestCard(2), CreateChestCard(3) },
                    },
                },
            },
        },
    }

    UI.SetRoot(UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                pointerEvents = "box-none",
                children = {
                    UI.Panel {
                        position = "absolute",
                        top = 16,
                        left = 18,
                        gap = 3,
                        pointerEvents = "none",
                        children = { healthLabel, roomLabel },
                    },
                    UI.Panel {
                        position = "absolute",
                        top = 16,
                        right = 18,
                        alignItems = "flex-end",
                        gap = 3,
                        pointerEvents = "none",
                        children = { parryLabel, abilityLabel },
                    },
                    UI.Label {
                        text = "WASD 移动   空格招架   F1 调试",
                        position = "absolute",
                        bottom = 14,
                        left = 0,
                        right = 0,
                        textAlign = "center",
                        fontSize = 11,
                        fontColor = { 212, 215, 245, 175 },
                        pointerEvents = "none",
                    },
                },
            },
            chestPanel,
        },
    })
end

local function RefreshChestPanel()
    if chestPanel == nil or game == nil then
        return
    end

    local isChoosing = game.state == "chest_select"
    chestPanel:SetVisible(isChoosing)
    if not isChoosing then
        return
    end

    for index = 1, 3 do
        local option = game.chestOptions and game.chestOptions[index] or nil
        chestCards[index]:SetVisible(option ~= nil)
        if option ~= nil then
            chestTitleLabels[index]:SetText(option.name)
            chestDescriptionLabels[index]:SetText(option.description)
        end
    end
end

local function UpdateHud()
    if game == nil or healthLabel == nil then
        return
    end

    local hud = Game.GetHud(game)
    healthLabel:SetText(hud.health)
    roomLabel:SetText(hud.room)
    parryLabel:SetText(hud.parry)
    abilityLabel:SetText("构筑\n" .. hud.upgrades)
    RefreshChestPanel()
end

function Start()
    graphics.windowTitle = Config.Title
    math.randomseed(os.time())
    RefreshCanvasMetrics()

    UI.Init({
        theme = "default-dark",
        fonts = { { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } } },
        scale = UI.Scale.DEFAULT,
    })
    CreateHud()

    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end
    if nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf") == -1 then
        print("WARNING: Could not load NanoVG font")
    end

    game = Game.New()
    UpdateHud()

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleNanoVGRender")
    print("弹反之室准备完成：按回车开始")
end

function Stop()
    UI.Shutdown()
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if game == nil then
        return
    end

    local dt = eventData:GetFloat("TimeStep")
    local moveX, moveY = 0, 0
    if input:GetKeyDown(KEY_A) then moveX = moveX - 1 end
    if input:GetKeyDown(KEY_D) then moveX = moveX + 1 end
    if input:GetKeyDown(KEY_W) then moveY = moveY - 1 end
    if input:GetKeyDown(KEY_S) then moveY = moveY + 1 end

    Game.Update(game, dt, moveX, moveY)
    hudTimer = hudTimer + dt
    if hudTimer >= 0.08 then
        UpdateHud()
        hudTimer = hudTimer - 0.08
    end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    if game == nil then
        return
    end

    local key = eventData:GetInt("Key")
    if game.state == "chest_select" then
        if key == KEY_1 then ChooseChestOption(1) end
        if key == KEY_2 then ChooseChestOption(2) end
        if key == KEY_3 then ChooseChestOption(3) end
        return
    end

    if key == KEY_F1 then
        Game.ToggleDebug(game)
        return
    end
    if key == KEY_RETURN and game.state == "menu" then
        Game.StartOrRestart(game)
        return
    end
    if key == KEY_SPACE then
        if game.state == "menu" then
            Game.StartOrRestart(game)
        else
            Game.TryParry(game)
        end
        return
    end
    if key == KEY_R and (game.state == "dead" or game.state == "victory") then
        Game.StartOrRestart(game)
    end
end

---@param eventType string
---@param eventData VariantMap
function HandleScreenMode(eventType, eventData)
    RefreshCanvasMetrics()
end

---@param eventType string
---@param eventData VariantMap
function HandleNanoVGRender(eventType, eventData)
    if nvgContext == nil or game == nil then
        return
    end

    nvgBeginFrame(nvgContext, logicalWidth, logicalHeight, devicePixelRatio)
    Renderer.Draw(nvgContext, game, logicalWidth, logicalHeight)
    nvgEndFrame(nvgContext)
end
