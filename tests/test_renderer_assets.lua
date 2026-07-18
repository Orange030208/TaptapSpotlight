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
assert(imagePaths[1] == "Characters/player.png")
assert(imagePaths[2] == "image/soot_monster.png")
assert(imagePaths[3] == "image/luminous_wraith_solid_alpha_20260718134330.png")
assert(imagePaths[4] == "image/stone_monster_rolling_20260718145411.png")
assert(imagePaths[5] == "image/dark_spore_mushroom_20260718151718.png")
assert(imagePaths[6] == "image/dark_dandelion_turret_20260718153010.png")
assert(imagePaths[7] == "image/toxic_purple_fluorescent_orb_20260718155838.png")
assert(imagePaths[8] == "image/low_toxic_purple_moss_20260718161117.png")
assert(imagePaths[9] == "image/spawn_room_wasd_floor_guide_20260718145203.png")
assert(imagePaths[10] == "image/spawn_room_left_click_parry_chalk_20260718151041.png")
assert(imagePaths[11] == "image/ui/lightning.png", "perfect streak lightning must load once with the renderer assets")

Renderer.UnloadAssets({})

local scaleCalls = {}
local rotationCalls = {}
local radialGradients = {}
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

assert(Renderer.LoadAssets({}))
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
local scaleCount = #scaleCalls
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
nvgImagePatternTinted = function()
    lightningPatternCalls = lightningPatternCalls + 1
    return {}
end
NVG_ALIGN_CENTER = 1
NVG_ALIGN_MIDDLE = 2
game.enemies = {}
Renderer.Draw({}, game, 960, 540, {
    time = 0.05,
    impacts = {}, shockwaves = {}, bursts = {}, floatingTexts = {}, flash = nil, shake = nil,
    perfectStreakDisplay = { count = 3, focusIndex = 3, life = 0.75, maxLife = 0.82 },
})
assert(lightningPatternCalls == 3, "a three-hit perfect streak must draw three tinted lightning cards")

local birthRoomGame = {
    time = 0, state = "clear", transition = nil, room = { isBirthRoom = true, connections = {} }, map = nil,
    enemies = {}, chests = {}, particles = {}, player = nil, spawnGuideAlpha = 1, spawnParryGuideAlpha = 1,
    projectiles = {
        { owner = "player", x = 0.5, y = 0.5, vx = 0.1, vy = 0, radius = 0.01, reflected = false },
    },
}
Renderer.Draw({}, birthRoomGame, 960, 540, nil)

Renderer.UnloadAssets({})
print("PASS test_renderer_assets")
