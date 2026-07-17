-- ============================================================================
-- Taptap Spotlight — 俄罗斯方块
-- 基于 templates/scaffold-2d.lua：纯 2D、无物理、NanoVG 矢量渲染。
-- 操作：← → 移动，↑ / X 旋转，↓ 软降，空格硬降，R 重新开始。
-- ============================================================================

local COLS = 10
local ROWS = 20
local INITIAL_DROP_INTERVAL = 0.75

local COLORS = {
    { 70, 225, 255 },   -- I: cyan
    { 255, 225, 75 },   -- O: yellow
    { 180, 100, 255 },  -- T: purple
    { 95, 235, 125 },   -- S: green
    { 255, 95, 120 },   -- Z: red
    { 75, 125, 255 },   -- J: blue
    { 255, 165, 70 },   -- L: orange
}

local TETROMINOES = {
    { name = "I", color = COLORS[1], blocks = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } } },
    { name = "O", color = COLORS[2], blocks = { { 1, 0 }, { 2, 0 }, { 1, 1 }, { 2, 1 } } },
    { name = "T", color = COLORS[3], blocks = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
    { name = "S", color = COLORS[4], blocks = { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } } },
    { name = "Z", color = COLORS[5], blocks = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } } },
    { name = "J", color = COLORS[6], blocks = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
    { name = "L", color = COLORS[7], blocks = { { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
}

---@type any
local nvgContext = nil
local fontId = -1
local board = {}
local activePiece = nil
local nextPieceIndex = 1
local gameState = "menu" -- menu, playing, gameover
local score = 0
local clearedLines = 0
local level = 1
local dropTimer = 0

local function CreateEmptyRow()
    local row = {}
    for x = 1, COLS do
        row[x] = nil
    end
    return row
end

local function CreateBoard()
    local newBoard = {}
    for y = 1, ROWS do
        newBoard[y] = CreateEmptyRow()
    end
    return newBoard
end

local function PickRandomPiece()
    return math.random(1, #TETROMINOES)
end

local function GetBlocks(piece, rotation)
    local blocks = {}

    for _, source in ipairs(piece.definition.blocks) do
        local x = source[1]
        local y = source[2]

        -- 除 O 外，所有方块都在 4×4 的旋转盒中顺时针旋转。
        if piece.definition.name ~= "O" then
            for _ = 1, rotation do
                x, y = 3 - y, x
            end
        end

        blocks[#blocks + 1] = { x, y }
    end

    return blocks
end

local function CanPlace(piece, pieceX, pieceY, rotation)
    for _, block in ipairs(GetBlocks(piece, rotation)) do
        local boardX = pieceX + block[1]
        local boardY = pieceY + block[2]

        if boardX < 0 or boardX >= COLS or boardY >= ROWS then
            return false
        end

        if boardY >= 0 and board[boardY + 1][boardX + 1] ~= nil then
            return false
        end
    end

    return true
end

local function GetDropInterval()
    return math.max(0.14, INITIAL_DROP_INTERVAL - (level - 1) * 0.055)
end

local function SpawnPiece()
    local pieceIndex = nextPieceIndex
    nextPieceIndex = PickRandomPiece()

    activePiece = {
        definition = TETROMINOES[pieceIndex],
        x = 3,
        y = -1,
        rotation = 0,
    }

    if not CanPlace(activePiece, activePiece.x, activePiece.y, activePiece.rotation) then
        gameState = "gameover"
        print("Game over: board is full")
    end
end

local function ResetGame()
    board = CreateBoard()
    score = 0
    clearedLines = 0
    level = 1
    dropTimer = 0
    nextPieceIndex = PickRandomPiece()
    gameState = "playing"
    SpawnPiece()
    print("Tetris game started")
end

local function ClearCompletedLines()
    local removed = 0
    local y = ROWS

    while y >= 1 do
        local complete = true
        for x = 1, COLS do
            if board[y][x] == nil then
                complete = false
                break
            end
        end

        if complete then
            table.remove(board, y)
            table.insert(board, 1, CreateEmptyRow())
            removed = removed + 1
        else
            y = y - 1
        end
    end

    if removed > 0 then
        local lineScores = { 0, 100, 300, 500, 800 }
        score = score + lineScores[removed + 1] * level
        clearedLines = clearedLines + removed
        level = math.floor(clearedLines / 10) + 1
        print("Cleared " .. tostring(removed) .. " line(s)")
    end
end

local function LockPiece()
    for _, block in ipairs(GetBlocks(activePiece, activePiece.rotation)) do
        local boardX = activePiece.x + block[1]
        local boardY = activePiece.y + block[2]

        if boardY < 0 then
            gameState = "gameover"
            print("Game over: locked above the board")
            return
        end

        board[boardY + 1][boardX + 1] = activePiece.definition.color
    end

    ClearCompletedLines()
    SpawnPiece()
end

local function TryMove(dx, dy)
    if activePiece == nil then
        return false
    end

    local newX = activePiece.x + dx
    local newY = activePiece.y + dy
    if not CanPlace(activePiece, newX, newY, activePiece.rotation) then
        return false
    end

    activePiece.x = newX
    activePiece.y = newY
    return true
end

local function TryRotate()
    if activePiece == nil then
        return
    end

    local newRotation = (activePiece.rotation + 1) % 4
    local wallKicks = { 0, -1, 1, -2, 2 }

    for _, offsetX in ipairs(wallKicks) do
        if CanPlace(activePiece, activePiece.x + offsetX, activePiece.y, newRotation) then
            activePiece.x = activePiece.x + offsetX
            activePiece.rotation = newRotation
            return
        end
    end
end

local function StepDown()
    if not TryMove(0, 1) then
        LockPiece()
    end
end

local function HardDrop()
    local distance = 0
    while TryMove(0, 1) do
        distance = distance + 1
    end
    score = score + distance * 2
    LockPiece()
end

-- ============================================================================
-- 生命周期：沿用 2D 脚手架的 Start / Update / Stop 结构。
-- ============================================================================

function Start()
    graphics.windowTitle = "Taptap Spotlight: Tetris"
    math.randomseed(os.time())

    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    fontId = nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf")
    if fontId == -1 then
        print("WARNING: Built-in font was not found; text will be hidden")
    end

    board = CreateBoard()
    nextPieceIndex = PickRandomPiece()

    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    print("Tetris ready: press Space or Enter to start")
end

function Stop()
    if nvgContext ~= nil then
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if gameState ~= "playing" then
        return
    end

    local timeStep = eventData:GetFloat("TimeStep")
    dropTimer = dropTimer + timeStep

    while dropTimer >= GetDropInterval() and gameState == "playing" do
        dropTimer = dropTimer - GetDropInterval()
        StepDown()
    end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")

    if gameState == "menu" or gameState == "gameover" then
        if key == KEY_SPACE or key == KEY_RETURN or key == KEY_R then
            ResetGame()
        end
        return
    end

    if key == KEY_LEFT then
        TryMove(-1, 0)
    elseif key == KEY_RIGHT then
        TryMove(1, 0)
    elseif key == KEY_DOWN then
        if TryMove(0, 1) then
            score = score + 1
        end
    elseif key == KEY_UP or key == KEY_X then
        TryRotate()
    elseif key == KEY_SPACE then
        HardDrop()
    elseif key == KEY_R then
        ResetGame()
    end
end

-- ============================================================================
-- NanoVG 绘制
-- ============================================================================

local function DrawRoundedRect(ctx, x, y, width, height, radius, color, alpha)
    local opacity = alpha or 255
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, width, height, radius)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], opacity))
    nvgFill(ctx)
end

local function DrawCell(ctx, x, y, cellSize, color, alpha)
    local padding = math.max(1, cellSize * 0.07)
    local size = cellSize - padding * 2
    DrawRoundedRect(ctx, x + padding, y + padding, size, size, math.max(2, cellSize * 0.12), color, alpha)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + padding, y + padding, size, size, math.max(2, cellSize * 0.12))
    nvgStrokeColor(ctx, nvgRGBA(255, 255, 255, alpha and math.floor(alpha * 0.38) or 105))
    nvgStrokeWidth(ctx, math.max(1, cellSize * 0.045))
    nvgStroke(ctx)
end

local function GetBoardLayout(width, height)
    local availableHeight = height - 155
    local availableWidth = width - 150
    local cellSize = math.floor(math.max(12, math.min(availableHeight / ROWS, availableWidth / 15)))
    local boardWidth = cellSize * COLS
    local boardHeight = cellSize * ROWS
    local boardX = math.floor((width - boardWidth) * 0.44)
    local boardY = math.floor((height - boardHeight) * 0.54)
    return boardX, boardY, cellSize, boardWidth, boardHeight
end

local function DrawBoardBackground(ctx, boardX, boardY, boardWidth, boardHeight)
    local shadow = nvgBoxGradient(ctx, boardX, boardY + 4, boardWidth, boardHeight, 14, 18,
        nvgRGBA(0, 0, 0, 150), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, boardX - 8, boardY - 8, boardWidth + 16, boardHeight + 16, 18)
    nvgFillPaint(ctx, shadow)
    nvgFill(ctx)

    DrawRoundedRect(ctx, boardX, boardY, boardWidth, boardHeight, 10, { 18, 24, 50 }, 255)

    for y = 0, ROWS do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, boardX, boardY + y * (boardHeight / ROWS))
        nvgLineTo(ctx, boardX + boardWidth, boardY + y * (boardHeight / ROWS))
        nvgStrokeColor(ctx, nvgRGBA(92, 115, 180, 38))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end

    for x = 0, COLS do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, boardX + x * (boardWidth / COLS), boardY)
        nvgLineTo(ctx, boardX + x * (boardWidth / COLS), boardY + boardHeight)
        nvgStrokeColor(ctx, nvgRGBA(92, 115, 180, 38))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
end

local function DrawPiece(ctx, piece, drawY, boardX, boardY, cellSize, alpha)
    for _, block in ipairs(GetBlocks(piece, piece.rotation)) do
        local cellX = piece.x + block[1]
        local cellY = drawY + block[2]
        if cellY >= 0 then
            DrawCell(ctx, boardX + cellX * cellSize, boardY + cellY * cellSize, cellSize, piece.definition.color, alpha)
        end
    end
end

local function DrawText(ctx, x, y, text, size, color, align)
    if fontId == -1 then
        return
    end

    nvgFontFaceId(ctx, fontId)
    nvgFontSize(ctx, size)
    nvgTextAlign(ctx, align)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(ctx, x, y, text, nil)
end

local function DrawSidePanel(ctx, boardX, boardY, boardWidth, cellSize)
    local panelX = boardX + boardWidth + cellSize * 0.8
    local panelY = boardY + cellSize * 0.5
    local panelWidth = math.max(110, cellSize * 4.5)

    DrawRoundedRect(ctx, panelX, panelY, panelWidth, cellSize * 7.3, 12, { 30, 38, 76 }, 235)
    DrawText(ctx, panelX + panelWidth / 2, panelY + cellSize * 0.7, "TETRIS", math.max(18, cellSize * 0.72), { 244, 247, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, panelX + cellSize * 0.45, panelY + cellSize * 1.8, "得分", math.max(12, cellSize * 0.38), { 175, 192, 255 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawText(ctx, panelX + cellSize * 0.45, panelY + cellSize * 2.55, tostring(score), math.max(21, cellSize * 0.72), { 255, 231, 118 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawText(ctx, panelX + cellSize * 0.45, panelY + cellSize * 3.55, "等级 " .. tostring(level), math.max(13, cellSize * 0.42), { 225, 230, 248 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawText(ctx, panelX + cellSize * 0.45, panelY + cellSize * 4.25, "消行 " .. tostring(clearedLines), math.max(13, cellSize * 0.42), { 225, 230, 248 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    DrawText(ctx, panelX + cellSize * 0.45, panelY + cellSize * 5.45, "下一个", math.max(12, cellSize * 0.38), { 175, 192, 255 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local preview = { definition = TETROMINOES[nextPieceIndex], x = 0, y = 0, rotation = 0 }
    for _, block in ipairs(GetBlocks(preview, 0)) do
        DrawCell(ctx, panelX + cellSize * 0.5 + block[1] * cellSize * 0.55, panelY + cellSize * 5.7 + block[2] * cellSize * 0.55,
            cellSize * 0.55, preview.definition.color, 255)
    end
end

local function DrawOverlay(ctx, width, height)
    if gameState == "playing" then
        return
    end

    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(3, 6, 20, 120))
    nvgFill(ctx)

    local title = gameState == "gameover" and "游戏结束" or "俄罗斯方块"
    local subtitle = gameState == "gameover" and "按 R、空格或回车重新开始" or "按 空格 或 回车 开始"
    DrawText(ctx, width / 2, height * 0.42, title, math.max(30, math.min(58, width * 0.08)), { 248, 249, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, width / 2, height * 0.49, subtitle, math.max(16, math.min(25, width * 0.035)), { 194, 210, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, width / 2, height * 0.57, "← → 移动    ↑ / X 旋转    ↓ 软降    空格 硬降", math.max(12, math.min(18, width * 0.026)), { 153, 174, 233 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then
        return
    end

    local width = graphics:GetWidth()
    local height = graphics:GetHeight()
    nvgBeginFrame(nvgContext, width, height, 1.0)

    local background = nvgLinearGradient(nvgContext, 0, 0, 0, height,
        nvgRGBA(20, 26, 62, 255), nvgRGBA(5, 8, 24, 255))
    nvgBeginPath(nvgContext)
    nvgRect(nvgContext, 0, 0, width, height)
    nvgFillPaint(nvgContext, background)
    nvgFill(nvgContext)

    local boardX, boardY, cellSize, boardWidth, boardHeight = GetBoardLayout(width, height)
    DrawBoardBackground(nvgContext, boardX, boardY, boardWidth, boardHeight)

    for y = 1, ROWS do
        for x = 1, COLS do
            local color = board[y][x]
            if color ~= nil then
                DrawCell(nvgContext, boardX + (x - 1) * cellSize, boardY + (y - 1) * cellSize, cellSize, color, 255)
            end
        end
    end

    if activePiece ~= nil then
        local ghostY = activePiece.y
        while CanPlace(activePiece, activePiece.x, ghostY + 1, activePiece.rotation) do
            ghostY = ghostY + 1
        end
        DrawPiece(nvgContext, activePiece, ghostY, boardX, boardY, cellSize, 60)
        DrawPiece(nvgContext, activePiece, activePiece.y, boardX, boardY, cellSize, 255)
    end

    DrawSidePanel(nvgContext, boardX, boardY, boardWidth, cellSize)
    DrawText(nvgContext, width / 2, math.max(22, boardY - 28), "Taptap Spotlight · Tetris", math.max(16, math.min(24, width * 0.035)), { 220, 228, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawOverlay(nvgContext, width, height)

    nvgEndFrame(nvgContext)
end
