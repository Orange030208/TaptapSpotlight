package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Renderer = require "Renderer"
local spineCreateCalls = 0
local imagePaths = {}

nvgSpineCreate = function()
    spineCreateCalls = spineCreateCalls + 1
    error("startup must not load an incompatible Spine asset")
end

nvgCreateImage = function(_, path)
    table.insert(imagePaths, path)
    return #imagePaths
end

nvgImageSize = function()
    return 64, 64
end

nvgDeleteImage = function() end

assert(Renderer.LoadAssets({}))
assert(spineCreateCalls == 0, "incompatible Spine 3.8 asset must not be loaded by the 4.2 runtime")
assert(imagePaths[1] == "Characters/player_animations/idle/idle_00.png")
assert(imagePaths[30] == "Characters/player_animations/idle/idle_29.png")
assert(imagePaths[31] == "Characters/player_animations/move/move_frame_00.png")
assert(imagePaths[60] == "Characters/player_animations/move/move_frame_29.png")
assert(imagePaths[61] == "Characters/player_animations/block/block_00.png")
assert(imagePaths[90] == "Characters/player_animations/block/block_29.png")
assert(imagePaths[91] == "image/soot_monster.png")
assert(imagePaths[92] == "image/blue_swarm.png")
assert(imagePaths[93] == "image/shadow_wraith.png")
assert(imagePaths[94] == "image/hard_slime.png")
assert(imagePaths[95] == "image/tree_wraith.png")
assert(imagePaths[96] == "image/stone_golem.png")
assert(imagePaths[97] == "image/spore_mushroom.png")
assert(imagePaths[98] == "image/dark_dandelion.png")
assert(imagePaths[99] == "image/purple_glow_orb.png")
assert(imagePaths[100] == "image/toxic_moss.png")
assert(imagePaths[101] == "image/projectile_spore.png")
assert(imagePaths[102] == "image/projectile_seed.png")
assert(imagePaths[103] == "image/spawn_room_wasd_floor_guide_20260718145203.png")
assert(imagePaths[104] == "image/spawn_room_left_click_parry_chalk_20260718151041.png")
assert(imagePaths[105] == "image/ui/lightning.png", "perfect streak lightning must load once with the renderer assets")
assert(imagePaths[106] == "image/ui/treasure_bag.png", "the treasure bag must load once with the renderer assets")
assert(imagePaths[107] == "image/forest_room.png", "the forest room map must load once with the renderer assets")
assert(imagePaths[108] == "image/forest_hands_foreground.png", "the forest hands foreground must load once with the renderer assets")

Renderer.UnloadAssets({})

local scaleCalls = {}
local rotationCalls = {}
local radialGradients = {}
local imagePatternHandles = {}
local roundedRectCalls = {}
local rootBezierCalls = 0
local noop = function() end
setmetatable(_G, {
    __index = function(_, name)
        if type(name) == "string" and name:sub(1, 3) == "nvg" then
            return noop
        end
    end,
})
nvgScale = function(_, x, y)
    table.insert(scaleCalls, { x = x, y = y })
end
nvgRotate = function(_, angle)
    table.insert(rotationCalls, angle)
end
nvgRGBA = function(r, g, b, a)
    return { r, g, b, a }
end
nvgRadialGradient = function(_, _, _, _, _, innerColor, outerColor)
    table.insert(radialGradients, { inner = innerColor, outer = outerColor })
    return {}
end
nvgImagePattern = function(_, _, _, _, _, imageHandle)
    table.insert(imagePatternHandles, imageHandle)
    return {}
end
nvgRoundedRect = function(_, x, y, width, height, radius)
    table.insert(roundedRectCalls, { x = x, y = y, width = width, height = height, radius = radius })
end
nvgBezierTo = function()
    rootBezierCalls = rootBezierCalls + 1
end

assert(Renderer.LoadAssets({}))
local player = {
    x = 0.5, y = 0.5, facing = "right", isMoving = false,
    parryTimer = 0, invulnerabilityTimer = 0,
}
local playerGame = {
    time = 0, state = "battle", transition = nil, room = nil, map = nil,
    enemies = {}, chests = {}, projectiles = {}, particles = {}, player = player,
}
Renderer.Draw({}, playerGame, 960, 540, nil)
assert(imagePaths[imagePatternHandles[#imagePatternHandles]] == "Characters/player_animations/idle/idle_00.png",
    "an idle player must use the idle frame animation")

player.isMoving = true
playerGame.time = 0.1
Renderer.Draw({}, playerGame, 960, 540, nil)
assert(imagePaths[imagePatternHandles[#imagePatternHandles]] == "Characters/player_animations/move/move_frame_00.png",
    "a moving player must use the move frame animation")

player.isMoving = false
player.parryTimer = 0.2
playerGame.time = 0.2
Renderer.Draw({}, playerGame, 960, 540, nil)
assert(imagePaths[imagePatternHandles[#imagePatternHandles]] == "Characters/player_animations/block/block_00.png",
    "a parrying player must use the block frame animation")

local soot = {
    kind = "soot", id = 1, x = 0.5, y = 0.5,
    vx = 0.1, vy = 0, facing = "left", state = "idle", stateTimer = 0,
    hp = 2, maxHp = 2, radius = 0.04,
}
local game = {
    time = 0, state = "battle", transition = nil, room = nil, map = nil,
    enemies = { soot }, chests = {}, projectiles = {}, particles = {}, player = nil,
}
Renderer.Draw({}, game, 960, 540, nil)
assert(scaleCalls[#scaleCalls].x > 0, "left-facing soot must keep the source sprite orientation")

soot.facing = "right"
Renderer.Draw({}, game, 960, 540, nil)
assert(scaleCalls[#scaleCalls].x < 0, "right-facing soot must mirror the source sprite")

local blueSwarm = {
    kind = "blue_swarm", id = 7, x = 0.5, y = 0.5,
    vx = 0.34, vy = 0, facing = "right", state = "telegraph", stateTimer = 0.1,
    hp = 2, maxHp = 2, radius = 0.04,
}
local gradientCount = #radialGradients
local scaleCount = #scaleCalls
game.enemies = { blueSwarm }
Renderer.Draw({}, game, 960, 540, nil)
assert(#scaleCalls > scaleCount, "blue swarm must animate as a sprite")
local hasBlueSwarmGlow = false
for index = gradientCount + 1, #radialGradients do
    local gradient = radialGradients[index]
    if gradient.inner[1] == 54 and gradient.inner[2] == 222 and gradient.inner[3] == 255 then
        hasBlueSwarmGlow = true
        break
    end
end
assert(hasBlueSwarmGlow, "blue swarm must gain a blue glow before its pulse")

local shadowWraith = {
    kind = "shadow_wraith", id = 8, x = 0.5, y = 0.5,
    vx = 0.2, vy = 0, facing = "right", state = "idle", stateTimer = 0,
    hp = 2, maxHp = 2, radius = 0.043,
}
scaleCount = #scaleCalls
game.enemies = { shadowWraith }
Renderer.Draw({}, game, 960, 540, nil)
assert(#scaleCalls > scaleCount, "shadow wraith must wave at its edges while moving")

local hardSlime = {
    kind = "sap", id = 18, x = 0.5, y = 0.5,
    vx = 0, vy = 0, facing = "right", state = "telegraph", stateTimer = 0.15,
    hp = 3, maxHp = 3, radius = 0.043,
}
scaleCount = #scaleCalls
game.enemies = { hardSlime }
Renderer.Draw({}, game, 960, 540, nil)
assert(#scaleCalls > scaleCount, "hard slime must compress before its melee arc attack")

local tree = {
    kind = "tree", id = 20, x = 0.5, y = 0.5,
    vx = 0, vy = 0, facing = "right", attackX = 1, attackY = 0, attackArc = 60,
    state = "telegraph", stateTimer = 0.275, hp = 3, maxHp = 3, radius = 0.055,
}
local treeRootCount = rootBezierCalls
scaleCount = #scaleCalls
game.enemies = { tree }
Renderer.Draw({}, game, 960, 540, nil)
assert(#scaleCalls > scaleCount, "tree wraith must render as a sprite")
assert(rootBezierCalls >= treeRootCount + 2, "tree must draw roots on both its front and rear sides")

local stone = {
    kind = "stone", id = 2, x = 0.5, y = 0.5,
    vx = 1.45, vy = 0, dashX = 1, dashY = 0,
    facing = "right", state = "dash", stateTimer = 0,
    hp = 3, maxHp = 3, radius = 0.052,
}
game.enemies = { stone }
Renderer.Draw({}, game, 960, 540, nil)
assert(#rotationCalls > 0, "rolling stone sprite must rotate during its charge")

local mushroom = {
    kind = "mushroom", id = 3, x = 0.5, y = 0.5,
    vx = 0, vy = 0, facing = "right", state = "telegraph", stateTimer = 0.035,
    hp = 2, maxHp = 2, radius = 0.04,
}
scaleCount = #scaleCalls
game.enemies = { mushroom }
game.projectiles = {
    {
        owner = "enemy", style = "spore", x = 0.5, y = 0.5,
        vx = 0.48, vy = 0, radius = 0.016, reflected = false,
    },
}
Renderer.Draw({}, game, 960, 540, nil)
assert(#scaleCalls > scaleCount, "mushroom sprite must squash during its spore attack")
local hasWhiteSporeHalo = false
for _, gradient in ipairs(radialGradients) do
    if gradient.inner[1] == 255 and gradient.inner[2] == 255 and gradient.inner[3] == 255 and gradient.inner[4] == 170
        and gradient.outer[1] == 255 and gradient.outer[2] == 255 and gradient.outer[3] == 255 and gradient.outer[4] == 0 then
        hasWhiteSporeHalo = true
        break
    end
end
assert(hasWhiteSporeHalo, "mushroom spores must use a white halo")

local dandelion = {
    kind = "dandelion", id = 4, x = 0.5, y = 0.5,
    vx = 0, vy = 0, facing = "right", state = "telegraph", stateTimer = 0.15,
    hp = 2, maxHp = 2, radius = 0.047,
}
local rotationCount = #rotationCalls
game.enemies = { dandelion }
game.projectiles = {}
Renderer.Draw({}, game, 960, 540, nil)
assert(#rotationCalls > rotationCount, "dark dandelion must shake during its seed release")

local purpleOrb = {
    kind = "purple_orb", id = 5, x = 0.5, y = 0.5,
    vx = 0, vy = 0, facing = "right", state = "telegraph", stateTimer = 0.125,
    hp = 2, maxHp = 2, radius = 0.043,
}
rotationCount = #rotationCalls
game.enemies = { purpleOrb }
Renderer.Draw({}, game, 960, 540, nil)
assert(#rotationCalls > rotationCount, "purple orb must shake before its AOE pulse")

local toxicMoss = {
    kind = "toxic_moss", id = 6, x = 0.5, y = 0.5,
    vx = 0, vy = 0, facing = "right", state = "idle", stateTimer = 0,
    hp = 1, maxHp = 1, radius = 0.07,
}
scaleCount = #scaleCalls
game.enemies = { toxicMoss }
Renderer.Draw({}, game, 960, 540, nil)
assert(#scaleCalls > scaleCount, "toxic moss must subtly jitter while idle")

local lightningPatternCalls = 0
local lightningAlphas = {}
nvgImagePatternTinted = function(_, _, _, _, _, _, _, color)
    lightningPatternCalls = lightningPatternCalls + 1
    table.insert(lightningAlphas, color[4])
    return {}
end
NVG_ALIGN_CENTER = 1
NVG_ALIGN_MIDDLE = 2
game.enemies = {}
Renderer.Draw({}, game, 960, 540, {
    time = 0.05,
    impacts = {}, shockwaves = {}, bursts = {}, floatingTexts = {}, flash = nil, shake = nil,
    perfectStreakDisplay = { count = 3, focusIndex = 3, life = 0.41, maxLife = 0.82 },
})
assert(lightningPatternCalls == 3, "a three-hit perfect streak must draw three tinted lightning cards")
assert(lightningAlphas[1] == 127, "lightning cards must fade continuously over their display lifetime")

local birthRoomGame = {
    time = 0, state = "clear", transition = nil, room = { isBirthRoom = true, connections = {} }, map = nil,
    enemies = {}, chests = {}, particles = {}, player = nil, spawnGuideAlpha = 1, spawnParryGuideAlpha = 1,
    projectiles = {
        { owner = "player", x = 0.5, y = 0.5, vx = 0.1, vy = 0, radius = 0.01, reflected = false },
    },
}
Renderer.Draw({}, birthRoomGame, 960, 540, nil)

roundedRectCalls = {}
local minimapGame = {
    time = 0, state = "battle", transition = nil,
    room = { id = "start", connections = { "boss" } },
    map = {
        rooms = {
            start = { id = "start", mapX = 0, mapY = 0, connections = { "boss" } },
            boss = { id = "boss", mapX = 1, mapY = -1, connections = { "start" }, boss = true },
        },
    },
    currentRoomId = "start",
    discoveredRooms = { start = true, boss = true },
    roomStates = { start = {}, boss = {} },
    enemies = {}, chests = {}, particles = {}, projectiles = {}, player = nil,
}
Renderer.Draw({}, minimapGame, 1000, 700, nil)

local minimapCell = nil
local minimapRight = -math.huge
for _, rect in ipairs(roundedRectCalls) do
    if math.abs(rect.width - 18.2) < 0.001 and math.abs(rect.height - 18.2) < 0.001 then
        minimapCell = rect
        minimapRight = math.max(minimapRight, rect.x + rect.width)
    end
end
assert(minimapCell ~= nil, "minimap cells must be enlarged to 18.2px in a 1000x700 viewport")
assert(math.abs(minimapRight - 984) < 0.001,
    "minimap's rightmost cell must keep a 16px right margin")

Renderer.UnloadAssets({})
print("PASS test_renderer_assets")
