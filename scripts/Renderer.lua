local PlayerConfig = require "Data.PlayerConfig"
local EnemyConfig = require "Data.EnemyConfig"
local ChestConfig = require "Data.ChestConfig"
local Feedback = require "Feedback"
local FeedbackConfig = require "Data.FeedbackConfig"
local BossRenderer = require "BossRenderer"

local Renderer = {}
local SOOT_SPRITE_PATH = "image/soot_monster.png"
local BLUE_SWARM_SPRITE_PATH = "image/blue_swarm.png"
local SHADOW_WRAITH_SPRITE_PATH = "image/shadow_wraith.png"
local HARD_SLIME_SPRITE_PATH = "image/hard_slime.png"
local TREE_WRAITH_SPRITE_PATH = "image/tree_wraith.png"
local STONE_SPRITE_PATH = "image/stone_golem.png"
local MUSHROOM_SPRITE_PATH = "image/spore_mushroom.png"
local DANDELION_SPRITE_PATH = "image/dark_dandelion.png"
local PURPLE_ORB_SPRITE_PATH = "image/purple_glow_orb.png"
local TOXIC_MOSS_SPRITE_PATH = "image/toxic_moss.png"
local SPAWN_ROOM_GUIDE_SPRITE_PATH = "image/spawn_room_wasd_floor_guide_20260718145203.png"
local SPAWN_ROOM_PARRY_GUIDE_SPRITE_PATH = "image/spawn_room_left_click_parry_chalk_20260718151041.png"
local PERFECT_STREAK_LIGHTNING_PATH = "image/ui/lightning.png"
local FOREST_ROOM_MAP_PATH = "image/forest_room.png"
local PLAYER_SPINE_PATH = "Characters/bard_cat/bard_cat.json"
local PLAYER_IDLE_ANIMATION = "move/STAND"
local PLAYER_MOVE_ANIMATION = "move/MOVE"
-- 当前资源由 Spine 3.8.75 导出，但运行时要求 Spine 4.2。
-- 在用 Spine 4.2 重新导出骨骼前，始终使用静态角色回退以避免原生崩溃。
local ENABLE_SPINE_PLAYER = false
local playerImageHandle = 0
local playerImageWidth = 1
local playerImageHeight = 1
local sootImageHandle = 0
local sootImageWidth = 1
local sootImageHeight = 1
local blueSwarmImageHandle = 0
local blueSwarmImageWidth = 1
local blueSwarmImageHeight = 1
local shadowWraithImageHandle = 0
local shadowWraithImageWidth = 1
local shadowWraithImageHeight = 1
local hardSlimeImageHandle = 0
local hardSlimeImageWidth = 1
local hardSlimeImageHeight = 1
local treeWraithImage = { handle = 0, width = 1, height = 1 }
local stoneImageHandle = 0
local stoneImageWidth = 1
local stoneImageHeight = 1
local mushroomImageHandle = 0
local mushroomImageWidth = 1
local mushroomImageHeight = 1
local dandelionImageHandle = 0
local dandelionImageWidth = 1
local dandelionImageHeight = 1
local purpleOrbImageHandle = 0
local purpleOrbImageWidth = 1
local purpleOrbImageHeight = 1
local toxicMossImageHandle = 0
local toxicMossImageWidth = 1
local toxicMossImageHeight = 1
local projectileSprites = {
    spore = { path = "image/projectile_spore.png", handle = 0, width = 1, height = 1 },
    seed = { path = "image/projectile_seed.png", handle = 0, width = 1, height = 1 },
}
local spawnRoomGuideImageHandle = 0
local spawnRoomGuideImageWidth = 1
local spawnRoomGuideImageHeight = 1
local spawnRoomParryGuideImageHandle = 0
local spawnRoomParryGuideImageWidth = 1
local spawnRoomParryGuideImageHeight = 1
local perfectStreakLightningImageHandle = 0
local perfectStreakLightningImageWidth = 1
local perfectStreakLightningImageHeight = 1
local forestRoomMapImageHandle = 0
---@type SpineInstance|nil
local playerSpine = nil
---@type string|nil
local playerSpineAnimation = nil
---@type number|nil
local playerSpineLastTime = nil

function Renderer.LoadAssets(ctx)
    local playerLoaded = false
    BossRenderer.LoadAssets(ctx)
    if ENABLE_SPINE_PLAYER then
        playerSpine = nvgSpineCreate(ctx)
    end
    if playerSpine ~= nil and playerSpine:Load(PLAYER_SPINE_PATH) then
        playerSpine:SetDefaultMix(0.12)
        playerSpine:SetAnimation(0, PLAYER_IDLE_ANIMATION, true)
        playerSpineAnimation = PLAYER_IDLE_ANIMATION
        playerSpineLastTime = nil
        playerLoaded = true
        print("Loaded Spine player character: " .. PLAYER_SPINE_PATH)
    else
        if playerSpine ~= nil then
            playerSpine:Unload()
            playerSpine:Dispose()
            playerSpine = nil
        end

        playerImageHandle = nvgCreateImage(ctx, "Characters/player.png", 0)
        if playerImageHandle == nil or playerImageHandle <= 0 then
            playerImageHandle = 0
            print("WARNING: Failed to load Spine player and static fallback: Characters/player.png")
        else
            playerImageWidth, playerImageHeight = nvgImageSize(ctx, playerImageHandle)
            if playerImageWidth <= 0 or playerImageHeight <= 0 then
                nvgDeleteImage(ctx, playerImageHandle)
                playerImageHandle = 0
                playerImageWidth, playerImageHeight = 1, 1
                print("WARNING: Player sprite fallback has invalid dimensions")
            else
                playerLoaded = true
            end
        end
    end

    local sootLoaded = true
    sootImageHandle = nvgCreateImage(ctx, SOOT_SPRITE_PATH, 0)
    if sootImageHandle == nil or sootImageHandle <= 0 then
        sootImageHandle = 0
        sootLoaded = false
        print("WARNING: Failed to load soot sprite: " .. SOOT_SPRITE_PATH .. "; using vector fallback")
    else
        sootImageWidth, sootImageHeight = nvgImageSize(ctx, sootImageHandle)
        if sootImageWidth <= 0 or sootImageHeight <= 0 then
            nvgDeleteImage(ctx, sootImageHandle)
            sootImageHandle = 0
            sootImageWidth, sootImageHeight = 1, 1
            sootLoaded = false
            print("WARNING: Soot sprite has invalid dimensions; using vector fallback")
        end
    end

    local blueSwarmLoaded = true
    blueSwarmImageHandle = nvgCreateImage(ctx, BLUE_SWARM_SPRITE_PATH, 0)
    if blueSwarmImageHandle == nil or blueSwarmImageHandle <= 0 then
        blueSwarmImageHandle = 0
        blueSwarmLoaded = false
        print("WARNING: Failed to load blue swarm sprite: " .. BLUE_SWARM_SPRITE_PATH .. "; using vector fallback")
    else
        blueSwarmImageWidth, blueSwarmImageHeight = nvgImageSize(ctx, blueSwarmImageHandle)
        if blueSwarmImageWidth <= 0 or blueSwarmImageHeight <= 0 then
            nvgDeleteImage(ctx, blueSwarmImageHandle)
            blueSwarmImageHandle = 0
            blueSwarmImageWidth, blueSwarmImageHeight = 1, 1
            blueSwarmLoaded = false
            print("WARNING: Blue swarm sprite has invalid dimensions; using vector fallback")
        end
    end

    local shadowWraithLoaded = true
    shadowWraithImageHandle = nvgCreateImage(ctx, SHADOW_WRAITH_SPRITE_PATH, 0)
    if shadowWraithImageHandle == nil or shadowWraithImageHandle <= 0 then
        shadowWraithImageHandle = 0
        shadowWraithLoaded = false
        print("WARNING: Failed to load shadow wraith sprite: " .. SHADOW_WRAITH_SPRITE_PATH .. "; using vector fallback")
    else
        shadowWraithImageWidth, shadowWraithImageHeight = nvgImageSize(ctx, shadowWraithImageHandle)
        if shadowWraithImageWidth <= 0 or shadowWraithImageHeight <= 0 then
            nvgDeleteImage(ctx, shadowWraithImageHandle)
            shadowWraithImageHandle = 0
            shadowWraithImageWidth, shadowWraithImageHeight = 1, 1
            shadowWraithLoaded = false
            print("WARNING: Shadow wraith sprite has invalid dimensions; using vector fallback")
        end
    end

    local hardSlimeLoaded = true
    hardSlimeImageHandle = nvgCreateImage(ctx, HARD_SLIME_SPRITE_PATH, 0)
    if hardSlimeImageHandle == nil or hardSlimeImageHandle <= 0 then
        hardSlimeImageHandle = 0
        hardSlimeLoaded = false
        print("WARNING: Failed to load hard slime sprite: " .. HARD_SLIME_SPRITE_PATH .. "; using vector fallback")
    else
        hardSlimeImageWidth, hardSlimeImageHeight = nvgImageSize(ctx, hardSlimeImageHandle)
        if hardSlimeImageWidth <= 0 or hardSlimeImageHeight <= 0 then
            nvgDeleteImage(ctx, hardSlimeImageHandle)
            hardSlimeImageHandle = 0
            hardSlimeImageWidth, hardSlimeImageHeight = 1, 1
            hardSlimeLoaded = false
            print("WARNING: Hard slime sprite has invalid dimensions; using vector fallback")
        end
    end

    local treeWraithLoaded = true
    treeWraithImage.handle = nvgCreateImage(ctx, TREE_WRAITH_SPRITE_PATH, 0)
    if treeWraithImage.handle == nil or treeWraithImage.handle <= 0 then
        treeWraithImage.handle = 0
        treeWraithLoaded = false
        print("WARNING: Failed to load tree wraith sprite: " .. TREE_WRAITH_SPRITE_PATH .. "; using vector fallback")
    else
        treeWraithImage.width, treeWraithImage.height = nvgImageSize(ctx, treeWraithImage.handle)
        if treeWraithImage.width <= 0 or treeWraithImage.height <= 0 then
            nvgDeleteImage(ctx, treeWraithImage.handle)
            treeWraithImage.handle = 0
            treeWraithImage.width, treeWraithImage.height = 1, 1
            treeWraithLoaded = false
            print("WARNING: Tree wraith sprite has invalid dimensions; using vector fallback")
        end
    end

    local stoneLoaded = true
    stoneImageHandle = nvgCreateImage(ctx, STONE_SPRITE_PATH, 0)
    if stoneImageHandle == nil or stoneImageHandle <= 0 then
        stoneImageHandle = 0
        stoneLoaded = false
        print("WARNING: Failed to load stone sprite: " .. STONE_SPRITE_PATH .. "; using vector fallback")
    else
        stoneImageWidth, stoneImageHeight = nvgImageSize(ctx, stoneImageHandle)
        if stoneImageWidth <= 0 or stoneImageHeight <= 0 then
            nvgDeleteImage(ctx, stoneImageHandle)
            stoneImageHandle = 0
            stoneImageWidth, stoneImageHeight = 1, 1
            stoneLoaded = false
            print("WARNING: Stone sprite has invalid dimensions; using vector fallback")
        end
    end

    local mushroomLoaded = true
    mushroomImageHandle = nvgCreateImage(ctx, MUSHROOM_SPRITE_PATH, 0)
    if mushroomImageHandle == nil or mushroomImageHandle <= 0 then
        mushroomImageHandle = 0
        mushroomLoaded = false
        print("WARNING: Failed to load mushroom sprite: " .. MUSHROOM_SPRITE_PATH .. "; using vector fallback")
    else
        mushroomImageWidth, mushroomImageHeight = nvgImageSize(ctx, mushroomImageHandle)
        if mushroomImageWidth <= 0 or mushroomImageHeight <= 0 then
            nvgDeleteImage(ctx, mushroomImageHandle)
            mushroomImageHandle = 0
            mushroomImageWidth, mushroomImageHeight = 1, 1
            mushroomLoaded = false
            print("WARNING: Mushroom sprite has invalid dimensions; using vector fallback")
        end
    end

    local dandelionLoaded = true
    dandelionImageHandle = nvgCreateImage(ctx, DANDELION_SPRITE_PATH, 0)
    if dandelionImageHandle == nil or dandelionImageHandle <= 0 then
        dandelionImageHandle = 0
        dandelionLoaded = false
        print("WARNING: Failed to load dandelion sprite: " .. DANDELION_SPRITE_PATH .. "; using vector fallback")
    else
        dandelionImageWidth, dandelionImageHeight = nvgImageSize(ctx, dandelionImageHandle)
        if dandelionImageWidth <= 0 or dandelionImageHeight <= 0 then
            nvgDeleteImage(ctx, dandelionImageHandle)
            dandelionImageHandle = 0
            dandelionImageWidth, dandelionImageHeight = 1, 1
            dandelionLoaded = false
            print("WARNING: Dandelion sprite has invalid dimensions; using vector fallback")
        end
    end

    local purpleOrbLoaded = true
    purpleOrbImageHandle = nvgCreateImage(ctx, PURPLE_ORB_SPRITE_PATH, 0)
    if purpleOrbImageHandle == nil or purpleOrbImageHandle <= 0 then
        purpleOrbImageHandle = 0
        purpleOrbLoaded = false
        print("WARNING: Failed to load purple orb sprite: " .. PURPLE_ORB_SPRITE_PATH .. "; using vector fallback")
    else
        purpleOrbImageWidth, purpleOrbImageHeight = nvgImageSize(ctx, purpleOrbImageHandle)
        if purpleOrbImageWidth <= 0 or purpleOrbImageHeight <= 0 then
            nvgDeleteImage(ctx, purpleOrbImageHandle)
            purpleOrbImageHandle = 0
            purpleOrbImageWidth, purpleOrbImageHeight = 1, 1
            purpleOrbLoaded = false
            print("WARNING: Purple orb sprite has invalid dimensions; using vector fallback")
        end
    end

    local toxicMossLoaded = true
    toxicMossImageHandle = nvgCreateImage(ctx, TOXIC_MOSS_SPRITE_PATH, 0)
    if toxicMossImageHandle == nil or toxicMossImageHandle <= 0 then
        toxicMossImageHandle = 0
        toxicMossLoaded = false
        print("WARNING: Failed to load toxic moss sprite: " .. TOXIC_MOSS_SPRITE_PATH .. "; using vector fallback")
    else
        toxicMossImageWidth, toxicMossImageHeight = nvgImageSize(ctx, toxicMossImageHandle)
        if toxicMossImageWidth <= 0 or toxicMossImageHeight <= 0 then
            nvgDeleteImage(ctx, toxicMossImageHandle)
            toxicMossImageHandle = 0
            toxicMossImageWidth, toxicMossImageHeight = 1, 1
            toxicMossLoaded = false
            print("WARNING: Toxic moss sprite has invalid dimensions; using vector fallback")
        end
    end

    local projectileSporeLoaded = true
    local projectileSpore = projectileSprites.spore
    projectileSpore.handle = nvgCreateImage(ctx, projectileSpore.path, 0)
    if projectileSpore.handle == nil or projectileSpore.handle <= 0 then
        projectileSpore.handle = 0
        projectileSporeLoaded = false
        print("WARNING: Failed to load spore projectile sprite: " .. projectileSpore.path .. "; using vector fallback")
    else
        projectileSpore.width, projectileSpore.height = nvgImageSize(ctx, projectileSpore.handle)
        if projectileSpore.width <= 0 or projectileSpore.height <= 0 then
            nvgDeleteImage(ctx, projectileSpore.handle)
            projectileSpore.handle = 0
            projectileSpore.width, projectileSpore.height = 1, 1
            projectileSporeLoaded = false
            print("WARNING: Spore projectile sprite has invalid dimensions; using vector fallback")
        end
    end

    local projectileSeedLoaded = true
    local projectileSeed = projectileSprites.seed
    projectileSeed.handle = nvgCreateImage(ctx, projectileSeed.path, 0)
    if projectileSeed.handle == nil or projectileSeed.handle <= 0 then
        projectileSeed.handle = 0
        projectileSeedLoaded = false
        print("WARNING: Failed to load seed projectile sprite: " .. projectileSeed.path .. "; using vector fallback")
    else
        projectileSeed.width, projectileSeed.height = nvgImageSize(ctx, projectileSeed.handle)
        if projectileSeed.width <= 0 or projectileSeed.height <= 0 then
            nvgDeleteImage(ctx, projectileSeed.handle)
            projectileSeed.handle = 0
            projectileSeed.width, projectileSeed.height = 1, 1
            projectileSeedLoaded = false
            print("WARNING: Seed projectile sprite has invalid dimensions; using vector fallback")
        end
    end

    local spawnRoomGuideLoaded = true
    spawnRoomGuideImageHandle = nvgCreateImage(ctx, SPAWN_ROOM_GUIDE_SPRITE_PATH, 0)
    if spawnRoomGuideImageHandle == nil or spawnRoomGuideImageHandle <= 0 then
        spawnRoomGuideImageHandle = 0
        spawnRoomGuideLoaded = false
        print("WARNING: Failed to load birth room guide: " .. SPAWN_ROOM_GUIDE_SPRITE_PATH)
    else
        spawnRoomGuideImageWidth, spawnRoomGuideImageHeight = nvgImageSize(ctx, spawnRoomGuideImageHandle)
        if spawnRoomGuideImageWidth <= 0 or spawnRoomGuideImageHeight <= 0 then
            nvgDeleteImage(ctx, spawnRoomGuideImageHandle)
            spawnRoomGuideImageHandle = 0
            spawnRoomGuideImageWidth, spawnRoomGuideImageHeight = 1, 1
            spawnRoomGuideLoaded = false
            print("WARNING: Birth room guide has invalid dimensions")
        end
    end

    local spawnRoomParryGuideLoaded = true
    spawnRoomParryGuideImageHandle = nvgCreateImage(ctx, SPAWN_ROOM_PARRY_GUIDE_SPRITE_PATH, 0)
    if spawnRoomParryGuideImageHandle == nil or spawnRoomParryGuideImageHandle <= 0 then
        spawnRoomParryGuideImageHandle = 0
        spawnRoomParryGuideLoaded = false
        print("WARNING: Failed to load birth room parry guide: " .. SPAWN_ROOM_PARRY_GUIDE_SPRITE_PATH)
    else
        spawnRoomParryGuideImageWidth, spawnRoomParryGuideImageHeight = nvgImageSize(ctx, spawnRoomParryGuideImageHandle)
        if spawnRoomParryGuideImageWidth <= 0 or spawnRoomParryGuideImageHeight <= 0 then
            nvgDeleteImage(ctx, spawnRoomParryGuideImageHandle)
            spawnRoomParryGuideImageHandle = 0
            spawnRoomParryGuideImageWidth, spawnRoomParryGuideImageHeight = 1, 1
            spawnRoomParryGuideLoaded = false
            print("WARNING: Birth room parry guide has invalid dimensions")
        end
    end

    local perfectStreakLightningLoaded = true
    perfectStreakLightningImageHandle = nvgCreateImage(ctx, PERFECT_STREAK_LIGHTNING_PATH, 0)
    if perfectStreakLightningImageHandle == nil or perfectStreakLightningImageHandle <= 0 then
        perfectStreakLightningImageHandle = 0
        perfectStreakLightningLoaded = false
        print("WARNING: Failed to load perfect streak lightning: " .. PERFECT_STREAK_LIGHTNING_PATH)
    else
        perfectStreakLightningImageWidth, perfectStreakLightningImageHeight = nvgImageSize(ctx, perfectStreakLightningImageHandle)
        if perfectStreakLightningImageWidth <= 0 or perfectStreakLightningImageHeight <= 0 then
            nvgDeleteImage(ctx, perfectStreakLightningImageHandle)
            perfectStreakLightningImageHandle = 0
            perfectStreakLightningImageWidth, perfectStreakLightningImageHeight = 1, 1
            perfectStreakLightningLoaded = false
            print("WARNING: Perfect streak lightning has invalid dimensions")
        end
    end

    forestRoomMapImageHandle = nvgCreateImage(ctx, FOREST_ROOM_MAP_PATH, 0)
    if forestRoomMapImageHandle == nil or forestRoomMapImageHandle <= 0 then
        forestRoomMapImageHandle = 0
        print("WARNING: Failed to load forest room map: " .. FOREST_ROOM_MAP_PATH)
    end

    return playerLoaded and sootLoaded and blueSwarmLoaded and shadowWraithLoaded and hardSlimeLoaded and treeWraithLoaded and stoneLoaded and mushroomLoaded and dandelionLoaded and purpleOrbLoaded and toxicMossLoaded and projectileSporeLoaded and projectileSeedLoaded and spawnRoomGuideLoaded
        and spawnRoomParryGuideLoaded and perfectStreakLightningLoaded and forestRoomMapImageHandle > 0
end

function Renderer.UnloadAssets(ctx)
    BossRenderer.UnloadAssets(ctx)
    if playerSpine ~= nil then
        playerSpine:Unload()
        playerSpine:Dispose()
        playerSpine = nil
    end
    playerSpineAnimation = nil
    playerSpineLastTime = nil

    if playerImageHandle ~= nil and playerImageHandle > 0 then
        nvgDeleteImage(ctx, playerImageHandle)
    end
    playerImageHandle = 0
    playerImageWidth, playerImageHeight = 1, 1
    if sootImageHandle ~= nil and sootImageHandle > 0 then
        nvgDeleteImage(ctx, sootImageHandle)
    end
    sootImageHandle = 0
    sootImageWidth, sootImageHeight = 1, 1
    if blueSwarmImageHandle ~= nil and blueSwarmImageHandle > 0 then
        nvgDeleteImage(ctx, blueSwarmImageHandle)
    end
    blueSwarmImageHandle = 0
    blueSwarmImageWidth, blueSwarmImageHeight = 1, 1
    if shadowWraithImageHandle ~= nil and shadowWraithImageHandle > 0 then
        nvgDeleteImage(ctx, shadowWraithImageHandle)
    end
    shadowWraithImageHandle = 0
    shadowWraithImageWidth, shadowWraithImageHeight = 1, 1
    if hardSlimeImageHandle ~= nil and hardSlimeImageHandle > 0 then
        nvgDeleteImage(ctx, hardSlimeImageHandle)
    end
    hardSlimeImageHandle = 0
    hardSlimeImageWidth, hardSlimeImageHeight = 1, 1
    if treeWraithImage.handle ~= nil and treeWraithImage.handle > 0 then
        nvgDeleteImage(ctx, treeWraithImage.handle)
    end
    treeWraithImage.handle = 0
    treeWraithImage.width, treeWraithImage.height = 1, 1
    if stoneImageHandle ~= nil and stoneImageHandle > 0 then
        nvgDeleteImage(ctx, stoneImageHandle)
    end
    stoneImageHandle = 0
    stoneImageWidth, stoneImageHeight = 1, 1
    if mushroomImageHandle ~= nil and mushroomImageHandle > 0 then
        nvgDeleteImage(ctx, mushroomImageHandle)
    end
    mushroomImageHandle = 0
    mushroomImageWidth, mushroomImageHeight = 1, 1
    if dandelionImageHandle ~= nil and dandelionImageHandle > 0 then
        nvgDeleteImage(ctx, dandelionImageHandle)
    end
    dandelionImageHandle = 0
    dandelionImageWidth, dandelionImageHeight = 1, 1
    if purpleOrbImageHandle ~= nil and purpleOrbImageHandle > 0 then
        nvgDeleteImage(ctx, purpleOrbImageHandle)
    end
    purpleOrbImageHandle = 0
    purpleOrbImageWidth, purpleOrbImageHeight = 1, 1
    if toxicMossImageHandle ~= nil and toxicMossImageHandle > 0 then
        nvgDeleteImage(ctx, toxicMossImageHandle)
    end
    toxicMossImageHandle = 0
    toxicMossImageWidth, toxicMossImageHeight = 1, 1
    for _, projectileSprite in pairs(projectileSprites) do
        if projectileSprite.handle ~= nil and projectileSprite.handle > 0 then
            nvgDeleteImage(ctx, projectileSprite.handle)
        end
        projectileSprite.handle = 0
        projectileSprite.width, projectileSprite.height = 1, 1
    end
    if spawnRoomGuideImageHandle ~= nil and spawnRoomGuideImageHandle > 0 then
        nvgDeleteImage(ctx, spawnRoomGuideImageHandle)
    end
    spawnRoomGuideImageHandle = 0
    spawnRoomGuideImageWidth, spawnRoomGuideImageHeight = 1, 1
    if spawnRoomParryGuideImageHandle ~= nil and spawnRoomParryGuideImageHandle > 0 then
        nvgDeleteImage(ctx, spawnRoomParryGuideImageHandle)
    end
    spawnRoomParryGuideImageHandle = 0
    spawnRoomParryGuideImageWidth, spawnRoomParryGuideImageHeight = 1, 1
    if perfectStreakLightningImageHandle ~= nil and perfectStreakLightningImageHandle > 0 then
        nvgDeleteImage(ctx, perfectStreakLightningImageHandle)
    end
    perfectStreakLightningImageHandle = 0
    perfectStreakLightningImageWidth, perfectStreakLightningImageHeight = 1, 1
    if forestRoomMapImageHandle ~= nil and forestRoomMapImageHandle > 0 then
        nvgDeleteImage(ctx, forestRoomMapImageHandle)
    end
    forestRoomMapImageHandle = 0
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function Atan2(y, x)
    return math.atan(y, x)
end

local function Color(ctx, color, alpha)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

local function StrokeColor(ctx, color, alpha)
    nvgStrokeColor(ctx, nvgRGBA(color[1], color[2], color[3], alpha or 255))
end

function Renderer.GetArena(width, height)
    local left = 0
    local right = width
    local top = 0
    local bottom = height
    local wallThickness = math.max(16, math.min(width, height) * 0.035)
    return {
        left = left,
        right = right,
        top = top,
        bottom = bottom,
        wallTop = height * 0.085,
        wallThickness = wallThickness,
    }
end

function Renderer.WorldToScreen(width, height, x, y)
    local arena = Renderer.GetArena(width, height)
    local scale = Clamp(math.min(width / 960, height / 720), 0.72, 1.35)
    return Lerp(arena.left, arena.right, x), Lerp(arena.top, arena.bottom, y), scale
end

function Renderer.ScreenToWorld(width, height, x, y)
    local arena = Renderer.GetArena(width, height)
    local arenaWidth = math.max(0.0001, arena.right - arena.left)
    local arenaHeight = math.max(0.0001, arena.bottom - arena.top)
    return (x - arena.left) / arenaWidth, (y - arena.top) / arenaHeight
end

local function DrawBackground(ctx, width, height, time)
    local gradient = nvgLinearGradient(ctx, 0, 0, 0, height,
        nvgRGBA(18, 18, 25, 255), nvgRGBA(31, 24, 35, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillPaint(ctx, gradient)
    nvgFill(ctx)

    local drift = (time * 6) % 42
    for index = -2, math.ceil(width / 42) + 2 do
        local x = index * 42 + drift
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, 0)
        nvgLineTo(ctx, x - height * 0.16, height)
        nvgStrokeWidth(ctx, 1)
        nvgStrokeColor(ctx, nvgRGBA(145, 120, 160, 18))
        nvgStroke(ctx)
    end
end

local function DrawDoor(ctx, arena, direction, isOpen, time)
    local floorWidth = arena.right - arena.left
    local floorHeight = arena.bottom - arena.top
    local glowColor = isOpen and { 95, 235, 213 } or { 255, 92, 174 }
    local coreColor = isOpen and { 218, 255, 244 } or { 255, 218, 235 }
    local pulse = 0.76 + 0.24 * math.sin(time * (isOpen and 3.2 or 2.1))
    local x, y, w, h

    if direction == "north" then
        w = floorWidth * 0.14
        h = floorHeight * 0.20
        x = (arena.left + arena.right - w) * 0.5
        y = floorHeight * 0.04
    elseif direction == "south" then
        w = floorWidth * 0.14
        h = floorHeight * 0.14
        x = (arena.left + arena.right - w) * 0.5
        y = arena.bottom - h
    elseif direction == "west" then
        w = floorWidth * 0.08
        h = floorHeight * 0.18
        x = arena.left
        y = (arena.top + arena.bottom - h) * 0.5
    else
        w = floorWidth * 0.08
        h = floorHeight * 0.18
        x = arena.right - w
        y = (arena.top + arena.bottom - h) * 0.5
    end

    local horizontal = direction == "north" or direction == "south"
    local glowSpread = isOpen and 18 or 12
    local frameInset = 4
    local curtainInset = 8

    -- 环境泛光：先铺一层柔和光晕，让门光自然映到墙面和地面。
    local outerGlow = nvgBoxGradient(ctx,
        x - glowSpread, y - glowSpread, w + glowSpread * 2, h + glowSpread * 2,
        8, glowSpread,
        nvgRGBA(glowColor[1], glowColor[2], glowColor[3], math.floor((isOpen and 96 or 82) * pulse)),
        nvgRGBA(glowColor[1], glowColor[2], glowColor[3], 0))
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - glowSpread, y - glowSpread,
        w + glowSpread * 2, h + glowSpread * 2, 8)
    nvgFillPaint(ctx, outerGlow)
    nvgFill(ctx)

    -- 深色实体门框。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, 3)
    nvgFillColor(ctx, nvgRGBA(8, 12, 23, 252))
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 4)
    nvgStrokeColor(ctx, nvgRGBA(31, 35, 52, 255))
    nvgStroke(ctx)

    -- 双层发光边缘，形成晶体门框的厚度。
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + frameInset, y + frameInset,
        math.max(1, w - frameInset * 2), math.max(1, h - frameInset * 2), 2)
    nvgStrokeWidth(ctx, isOpen and 3.2 or 2.4)
    StrokeColor(ctx, glowColor, math.floor((isOpen and 230 or 170) * pulse))
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + frameInset + 2, y + frameInset + 2,
        math.max(1, w - (frameInset + 2) * 2), math.max(1, h - (frameInset + 2) * 2), 1)
    nvgStrokeWidth(ctx, 1.2)
    StrokeColor(ctx, coreColor, math.floor((isOpen and 235 or 155) * pulse))
    nvgStroke(ctx)

    -- 半透明能量光幕，开放时更明亮、更通透。
    local curtainX = x + curtainInset
    local curtainY = y + curtainInset
    local curtainW = math.max(1, w - curtainInset * 2)
    local curtainH = math.max(1, h - curtainInset * 2)
    local curtainGradient
    if horizontal then
        curtainGradient = nvgLinearGradient(ctx, curtainX, curtainY,
            curtainX, curtainY + curtainH,
            nvgRGBA(coreColor[1], coreColor[2], coreColor[3], math.floor((isOpen and 205 or 95) * pulse)),
            nvgRGBA(glowColor[1], glowColor[2], glowColor[3], isOpen and 52 or 30))
    else
        curtainGradient = nvgLinearGradient(ctx, curtainX, curtainY,
            curtainX + curtainW, curtainY,
            nvgRGBA(coreColor[1], coreColor[2], coreColor[3], math.floor((isOpen and 205 or 95) * pulse)),
            nvgRGBA(glowColor[1], glowColor[2], glowColor[3], isOpen and 52 or 30))
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, curtainX, curtainY, curtainW, curtainH)
    nvgFillPaint(ctx, curtainGradient)
    nvgFill(ctx)

    -- 缓慢流动的光丝，让门保持有生命的能量感。
    local strandCount = 3
    for index = 1, strandCount do
        local phase = (time * (isOpen and 0.42 or 0.18) + index / strandCount) % 1
        nvgBeginPath(ctx)
        if horizontal then
            local strandX = curtainX + curtainW * phase
            nvgMoveTo(ctx, strandX, curtainY + 1)
            nvgLineTo(ctx, strandX, curtainY + curtainH - 1)
        else
            local strandY = curtainY + curtainH * phase
            nvgMoveTo(ctx, curtainX + 1, strandY)
            nvgLineTo(ctx, curtainX + curtainW - 1, strandY)
        end
        nvgStrokeWidth(ctx, index == 2 and 1.8 or 1.0)
        StrokeColor(ctx, coreColor, math.floor((isOpen and 135 or 65) * pulse))
        nvgStroke(ctx)
    end

    -- 中央光核强化远距离识别；封闭门显示收束的封印裂纹。
    local centerX = x + w * 0.5
    local centerY = y + h * 0.5
    local coreRadius = math.max(2.5, math.min(w, h) * (isOpen and 0.11 or 0.09))
    nvgBeginPath(ctx)
    nvgCircle(ctx, centerX, centerY, coreRadius * 3.2)
    nvgFillPaint(ctx, nvgRadialGradient(ctx, centerX, centerY, 0, coreRadius * 3.2,
        nvgRGBA(coreColor[1], coreColor[2], coreColor[3], math.floor((isOpen and 145 or 85) * pulse)),
        nvgRGBA(glowColor[1], glowColor[2], glowColor[3], 0)))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, centerX, centerY, coreRadius)
    nvgFillColor(ctx, nvgRGBA(coreColor[1], coreColor[2], coreColor[3],
        math.floor((isOpen and 245 or 195) * pulse)))
    nvgFill(ctx)

    if not isOpen then
        nvgBeginPath(ctx)
        if horizontal then
            nvgMoveTo(ctx, x + w * 0.24, centerY - h * 0.18)
            nvgLineTo(ctx, centerX, centerY)
            nvgLineTo(ctx, x + w * 0.76, centerY + h * 0.18)
            nvgMoveTo(ctx, x + w * 0.76, centerY - h * 0.18)
            nvgLineTo(ctx, centerX, centerY)
            nvgLineTo(ctx, x + w * 0.24, centerY + h * 0.18)
        else
            nvgMoveTo(ctx, centerX - w * 0.18, y + h * 0.24)
            nvgLineTo(ctx, centerX, centerY)
            nvgLineTo(ctx, centerX + w * 0.18, y + h * 0.76)
            nvgMoveTo(ctx, centerX + w * 0.18, y + h * 0.24)
            nvgLineTo(ctx, centerX, centerY)
            nvgLineTo(ctx, centerX - w * 0.18, y + h * 0.76)
        end
        nvgStrokeWidth(ctx, 2)
        StrokeColor(ctx, coreColor, math.floor(180 * pulse))
        nvgStroke(ctx)
    end
end

local function DrawSpawnRoomWallLights(ctx, width, height, game, arena)
    if game.room == nil or not game.room.isBirthRoom then
        return
    end

    local _, _, scale = Renderer.WorldToScreen(width, height, 0.5, 0.47)
    local pulse = 0.62 + 0.38 * math.sin(game.time * 2.2)
    for _, light in ipairs({
        { x = arena.left + (arena.right - arena.left) * 0.14, y = arena.top + 24 },
        { x = arena.right - (arena.right - arena.left) * 0.14, y = arena.top + 24 },
    }) do
        nvgBeginPath(ctx)
        nvgCircle(ctx, light.x, light.y, 22 * scale)
        nvgFillPaint(ctx, nvgRadialGradient(ctx, light.x, light.y, 2, 22 * scale,
            nvgRGBA(255, 205, 126, math.floor(72 * pulse)), nvgRGBA(255, 168, 100, 0)))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, light.x, light.y, math.max(2, 3 * scale))
        nvgFillColor(ctx, nvgRGBA(255, 231, 175, math.floor(190 + 45 * pulse)))
        nvgFill(ctx)
    end
end

local function DrawArena(ctx, width, height, game)
    local arena = Renderer.GetArena(width, height)
    if game.room ~= nil and game.room.mapImage == FOREST_ROOM_MAP_PATH and forestRoomMapImageHandle > 0 then
        nvgBeginPath(ctx)
        nvgRect(ctx, arena.left, arena.top, arena.right - arena.left, arena.bottom - arena.top)
        nvgFillPaint(ctx, nvgImagePattern(ctx, arena.left, arena.top,
            arena.right - arena.left, arena.bottom - arena.top, 0, forestRoomMapImageHandle, 1.0))
        nvgFill(ctx)

        for _, direction in ipairs({ "north", "west", "east" }) do
            if game.room.connections[direction] ~= nil then
                DrawDoor(ctx, arena, direction, game.roomCleared, game.time)
            end
        end
        return
    end
    local floorGradient = nvgLinearGradient(ctx, 0, arena.top, 0, arena.bottom,
        nvgRGBA(71, 64, 78, 255), nvgRGBA(43, 39, 50, 255))

    nvgBeginPath(ctx)
    nvgRect(ctx, arena.left, arena.top, arena.right - arena.left, arena.bottom - arena.top)
    nvgFillPaint(ctx, floorGradient)
    nvgFill(ctx)

    -- Tile grid stays rectangular: no forced-perspective tapering.
    for column = 1, 9 do
        local x = Lerp(arena.left, arena.right, column / 10)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, arena.top)
        nvgLineTo(ctx, x, arena.bottom)
        nvgStrokeWidth(ctx, 1)
        StrokeColor(ctx, { 196, 181, 205 }, 26)
        nvgStroke(ctx)
    end
    for row = 1, 7 do
        local y = Lerp(arena.top, arena.bottom, row / 8)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, arena.left, y)
        nvgLineTo(ctx, arena.right, y)
        nvgStrokeWidth(ctx, 1)
        StrokeColor(ctx, { 196, 181, 205 }, 30)
        nvgStroke(ctx)
    end

    DrawSpawnRoomWallLights(ctx, width, height, game, arena)

    -- Tall back wall makes the upper wall face visible in the 2.5D view.
    local backWallGradient = nvgLinearGradient(ctx, 0, arena.wallTop, 0, arena.top,
        nvgRGBA(104, 86, 108, 255), nvgRGBA(65, 53, 72, 255))
    nvgBeginPath(ctx)
    nvgRect(ctx, arena.left - arena.wallThickness, arena.wallTop,
        arena.right - arena.left + arena.wallThickness * 2, arena.top - arena.wallTop)
    nvgFillPaint(ctx, backWallGradient)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, arena.left - arena.wallThickness, arena.top,
        arena.wallThickness, arena.bottom - arena.top + arena.wallThickness)
    nvgRect(ctx, arena.right, arena.top,
        arena.wallThickness, arena.bottom - arena.top + arena.wallThickness)
    nvgRect(ctx, arena.left, arena.bottom,
        arena.right - arena.left, arena.wallThickness)
    nvgFillColor(ctx, nvgRGBA(73, 60, 78, 255))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, arena.left - arena.wallThickness, arena.top)
    nvgLineTo(ctx, arena.right + arena.wallThickness, arena.top)
    nvgStrokeWidth(ctx, 4)
    StrokeColor(ctx, { 143, 118, 142 }, 210)
    nvgStroke(ctx)

    if game.room ~= nil then
        for _, direction in ipairs({ "north", "south", "west", "east" }) do
            if game.room.connections[direction] ~= nil then
                DrawDoor(ctx, arena, direction, game.roomCleared, game.time)
            end
        end
    end
end

local function DrawSpawnMarkers(ctx, width, height, game)
    if game.room == nil then
        return
    end

    local spawns = game.room.fixedSpawns or game.room.spawns
    if spawns == nil then
        return
    end

    for _, spawn in ipairs(spawns) do
        local x, y, scale = Renderer.WorldToScreen(width, height, spawn.x, spawn.y)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, 20 * scale)
        nvgStrokeWidth(ctx, 2)
        StrokeColor(ctx, { 255, 210, 115 }, 180)
        nvgStroke(ctx)
    end
end

local function DrawShadow(ctx, x, y, scale, width, alpha)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, y + 10 * scale, width * scale, 5 * scale)
    nvgFillColor(ctx, nvgRGBA(5, 5, 16, alpha))
    nvgFill(ctx)
end

local function DrawFallbackPlayer(ctx, width, height, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, player.x, player.y)
    scale = scale * PlayerConfig.sizeMultiplier
    local bodyW = 19 * scale
    local bodyH = 29 * scale
    local flip = player.facing == "left" and -1 or 1
    local bob = math.sin(time * 10) * 1.2 * scale

    DrawShadow(ctx, x, y, scale, 16, 125)
    nvgSave(ctx)
    nvgTranslate(ctx, x, y + bob)
    nvgScale(ctx, flip, 1)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, -bodyW * 0.5, -bodyH, bodyW, bodyH, 7 * scale)
    Color(ctx, { 100, 210, 255 }, player.invulnerabilityTimer > 0 and 160 or 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, { 220, 248, 255 }, 255)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgCircle(ctx, bodyW * 0.18, -bodyH * 0.68, 3.4 * scale)
    Color(ctx, { 22, 30, 62 }, 255)
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, bodyW * 0.15, -bodyH * 0.42, bodyW * 0.8, 5 * scale, 2 * scale)
    Color(ctx, { 255, 235, 132 }, 255)
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function DrawSpritePlayer(ctx, width, height, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, player.x, player.y)
    scale = scale * PlayerConfig.sizeMultiplier
    local displayHeight = 58 * scale
    local displayWidth = displayHeight * playerImageWidth / playerImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight
    local flip = player.facing == "left" and -1 or 1
    local bob = math.sin(time * 10) * 1.2 * scale
    local imageAlpha = 1.0
    if player.invulnerabilityTimer > 0 then
        imageAlpha = 0.42 + 0.38 * math.abs(math.sin(time * 24))
    end

    DrawShadow(ctx, x, y, scale, 23, 135)
    nvgSave(ctx)
    nvgTranslate(ctx, x, y + bob)
    nvgScale(ctx, flip, 1)

    if player.parryTimer > 0 then
        nvgSave(ctx)
        nvgScale(ctx, 1.08, 1.08)
        nvgTranslate(ctx, 0, displayHeight * 0.07)
        nvgBeginPath(ctx)
        nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
        nvgFillPaint(ctx, nvgImagePatternTinted(
            ctx, drawX, drawY, displayWidth, displayHeight, 0, playerImageHandle,
            nvgRGBA(110, 235, 255, 125)
        ))
        nvgFill(ctx)
        nvgRestore(ctx)
    end

    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, playerImageHandle, imageAlpha))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function UpdatePlayerSpineAnimation(player, time)
    if playerSpine == nil or not playerSpine:IsLoaded() then
        return
    end

    local animation = player.isMoving and PLAYER_MOVE_ANIMATION or PLAYER_IDLE_ANIMATION
    if playerSpineAnimation ~= animation then
        if not playerSpine:SetAnimation(0, animation, true) then
            print("WARNING: Missing player Spine animation: " .. animation)
        end
        playerSpineAnimation = animation
    end

    local deltaTime = 0
    if playerSpineLastTime ~= nil then
        deltaTime = Clamp(time - playerSpineLastTime, 0, 0.1)
    end
    playerSpineLastTime = time
    if deltaTime > 0 then
        playerSpine:Update(deltaTime)
    end
end

local function DrawSpinePose(ctx, displayHeight, flip, red, green, blue, alpha)
    if playerSpine == nil then
        return false
    end

    local dataWidth = playerSpine:GetDataWidth()
    local dataHeight = playerSpine:GetDataHeight()
    if dataWidth <= 0 or dataHeight <= 0 then
        return false
    end

    local scale = displayHeight / dataHeight
    local displayWidth = dataWidth * scale
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight
    local dataX = playerSpine:GetDataX()
    local dataY = playerSpine:GetDataY()

    playerSpine:SetScale(scale * flip, -scale)
    playerSpine:SetPosition(
        drawX + (flip < 0 and (dataWidth + dataX) or -dataX) * scale,
        drawY + (dataHeight + dataY) * scale
    )
    playerSpine:SetColor(red, green, blue, alpha)
    nvgSpineRender(ctx, playerSpine)
    return true
end

local function DrawSpinePlayer(ctx, width, height, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, player.x, player.y)
    scale = scale * PlayerConfig.sizeMultiplier
    local displayHeight = 58 * scale
    local flip = player.facing == "left" and -1 or 1
    local bob = math.sin(time * 10) * 1.2 * scale
    local alpha = 1.0
    if player.invulnerabilityTimer > 0 then
        alpha = 0.42 + 0.38 * math.abs(math.sin(time * 24))
    end

    UpdatePlayerSpineAnimation(player, time)
    DrawShadow(ctx, x, y, scale, 23, 135)
    nvgSave(ctx)
    nvgTranslate(ctx, x, y + bob)
    if player.parryTimer > 0 then
        DrawSpinePose(ctx, displayHeight * 1.08, flip, 110 / 255, 235 / 255, 1.0, 0.49)
    end
    DrawSpinePose(ctx, displayHeight, flip, 1.0, 1.0, 1.0, alpha)
    nvgRestore(ctx)
end

local function DrawPlayer(ctx, width, height, player, time)
    if playerSpine ~= nil and playerSpine:IsLoaded() then
        DrawSpinePlayer(ctx, width, height, player, time)
    elseif playerImageHandle ~= nil and playerImageHandle > 0 then
        DrawSpritePlayer(ctx, width, height, player, time)
    else
        DrawFallbackPlayer(ctx, width, height, player, time)
    end
end

local function EnemyColor(kind)
    local spec = EnemyConfig[kind]
    if spec ~= nil and spec.visual ~= nil then
        return spec.visual.primary
    end
    return { 255, 145, 74 }
end

local function BuildSectorPath(ctx, centerX, centerY, radiusX, radiusY, startAngle, arcRadians)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, centerX, centerY)
    for step = 0, 28 do
        local angle = startAngle + arcRadians * step / 28
        nvgLineTo(ctx, centerX + math.cos(angle) * radiusX, centerY + math.sin(angle) * radiusY)
    end
    nvgClosePath(ctx)
end

local function GetWorldRadius(width, height, worldRadius)
    local arena = Renderer.GetArena(width, height)
    return (arena.right - arena.left) * worldRadius, (arena.bottom - arena.top) * worldRadius
end

local function DrawCircleAttackRegion(ctx, centerX, centerY, radiusX, radiusY, color, progress, pulse, scale)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, centerX, centerY, radiusX, radiusY)
    Color(ctx, color, 42)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.4 * scale)
    StrokeColor(ctx, color, pulse)
    nvgStroke(ctx)

    if progress > 0 then
        nvgBeginPath(ctx)
        nvgEllipse(ctx, centerX, centerY, radiusX * progress, radiusY * progress)
        Color(ctx, color, 105)
        nvgFill(ctx)
    end
end

local function DrawSectorAttackRegion(ctx, centerX, centerY, radiusX, radiusY, startAngle, arcRadians, color, progress, pulse, scale)
    BuildSectorPath(ctx, centerX, centerY, radiusX, radiusY, startAngle, arcRadians)
    Color(ctx, color, 38)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.2 * scale)
    StrokeColor(ctx, color, pulse)
    nvgStroke(ctx)

    if progress > 0 then
        BuildSectorPath(ctx, centerX, centerY, radiusX * progress, radiusY * progress, startAngle, arcRadians)
        Color(ctx, color, 110)
        nvgFill(ctx)
    end
end

local function DrawDashAttackRegion(ctx, centerX, centerY, radiusX, radiusY, widthX, widthY, directionAngle, color, progress, pulse, scale)
    local sideX = math.cos(directionAngle + math.pi * 0.5) * widthX
    local sideY = math.sin(directionAngle + math.pi * 0.5) * widthY
    local endX = math.cos(directionAngle) * radiusX
    local endY = math.sin(directionAngle) * radiusY

    local function BuildDashPath(distance)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, centerX - sideX, centerY - sideY)
        nvgLineTo(ctx, centerX + sideX, centerY + sideY)
        nvgLineTo(ctx, centerX + endX * distance + sideX, centerY + endY * distance + sideY)
        nvgLineTo(ctx, centerX + endX * distance - sideX, centerY + endY * distance - sideY)
        nvgClosePath(ctx)
    end

    BuildDashPath(1)
    Color(ctx, color, 42)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.4 * scale)
    StrokeColor(ctx, color, pulse)
    nvgStroke(ctx)
    if progress > 0 then
        BuildDashPath(progress)
        Color(ctx, color, 110)
        nvgFill(ctx)
    end
end

local function DrawEnemyTelegraph(ctx, width, height, enemy, player)
    if enemy.state ~= "telegraph" then
        return
    end
    local x, y, scale = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    local spec = EnemyConfig[enemy.kind]
    if spec == nil or spec.attack == nil then
        return
    end

    local attack = spec.attack
    local progress = Clamp(1 - enemy.stateTimer / math.max(0.001, attack.telegraph), 0, 1)
    local pulse = 155 + math.floor(85 * math.abs(math.sin(enemy.stateTimer * 13)))
    local directionX, directionY = enemy.attackX or 1, enemy.attackY or 0
    local directionAngle = Atan2(directionY, directionX)
    local telegraphColor = enemy.kind == "blue_swarm" and { 70, 225, 255 } or { 255, 230, 120 }
    local behavior = spec.behavior or ""
    if behavior == "ranged_single" or behavior == "ranged_fan" then
        return
    end
    local attackRange = attack.range or spec.attackRange or enemy.radius * 2
    if behavior == "melee_arc" or behavior == "tree_swing" then
        attackRange = attackRange + enemy.radius + PlayerConfig.radius
    elseif behavior == "aoe_pulse" then
        attackRange = attackRange + PlayerConfig.radius
    end
    local radiusX, radiusY = GetWorldRadius(width, height, attackRange)
    radiusX = math.max(radiusX, 8 * scale)
    radiusY = math.max(radiusY, 8 * scale)

    if behavior == "aoe_pulse" then
        DrawCircleAttackRegion(ctx, x, y, radiusX, radiusY, telegraphColor, progress, pulse, scale)
    elseif behavior == "tree_swing" then
        local arc = math.rad(enemy.attackArc or attack.arc or 60)
        DrawSectorAttackRegion(ctx, x, y, radiusX, radiusY, directionAngle - arc * 0.5, arc,
            { 222, 150, 255 }, progress, pulse, scale)
        DrawSectorAttackRegion(ctx, x, y, radiusX, radiusY, directionAngle + math.pi - arc * 0.5, arc,
            { 222, 150, 255 }, progress, pulse, scale)
    elseif behavior == "melee_arc" then
        local arc = math.rad(enemy.attackArc or attack.arc or 70)
        DrawSectorAttackRegion(ctx, x, y, radiusX, radiusY, directionAngle - arc * 0.5, arc,
            telegraphColor, progress, pulse, scale)
    elseif behavior == "melee_lunge" or behavior == "rolling" then
        local dashLength = math.max(attackRange, (attack.active or 0) * (attack.dashSpeed or 0))
        local dashRadiusX, dashRadiusY = GetWorldRadius(width, height, dashLength)
        local dashWidthX, dashWidthY = GetWorldRadius(width, height, math.max(enemy.radius + 0.012, PlayerConfig.radius))
        DrawDashAttackRegion(ctx, x, y, dashRadiusX, dashRadiusY, dashWidthX, dashWidthY, directionAngle,
            telegraphColor, progress, pulse, scale)
    end
end

local function DrawEnemyMotionTrail(ctx, width, height, enemy)
    if enemy.state ~= "idle" then
        return
    end
    local speed = math.sqrt(enemy.vx * enemy.vx + enemy.vy * enemy.vy)
    if speed <= 0.01 then
        return
    end
    local tailX = enemy.x - enemy.vx * 0.25
    local tailY = enemy.y - enemy.vy * 0.25
    local x, y = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    local previousX, previousY = Renderer.WorldToScreen(width, height, tailX, tailY)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, previousX, previousY)
    nvgLineTo(ctx, x, y)
    nvgStrokeWidth(ctx, 2)
    StrokeColor(ctx, EnemyColor(enemy.kind), 85)
    nvgStroke(ctx)
end

local function DrawEyes(ctx, x, y, scale, spacing, eyeColor)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x - spacing, y, 3.6 * scale)
    nvgCircle(ctx, x + spacing, y, 3.6 * scale)
    Color(ctx, eyeColor or { 255, 249, 231 }, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x - spacing + scale, y + scale * 0.5, 1.25 * scale)
    nvgCircle(ctx, x + spacing + scale, y + scale * 0.5, 1.25 * scale)
    Color(ctx, { 25, 26, 39 }, 255)
    nvgFill(ctx)
end

local function DrawSoot(ctx, x, y, size, scale, time, color, secondary)
    local centerY = y - size * 0.58
    for index = 1, 6 do
        local angle = index * math.pi * 2 / 6 + time * 0.5
        local radius = size * (0.16 + (index % 3) * 0.025)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x + math.cos(angle) * size * 0.32, centerY + math.sin(angle) * size * 0.25, radius)
        Color(ctx, index % 2 == 0 and secondary or color, 245)
        nvgFill(ctx)
    end
    DrawEyes(ctx, x, centerY - size * 0.04, scale, size * 0.14)
end

local function GetSootSpriteHeight(scale)
    return 42 * scale
end

local function GetSootSquashStretch(enemy, time)
    local speed = math.sqrt(enemy.vx * enemy.vx + enemy.vy * enemy.vy)
    local rhythm = math.sin(time * (4.8 + math.min(speed, 1) * 12) + enemy.id * 0.67)
    local scaleX = 1 + rhythm * (speed > 0.01 and 0.055 or 0.025)
    local scaleY = 1 - rhythm * (speed > 0.01 and 0.045 or 0.02)
    local spec = EnemyConfig.soot

    if enemy.state == "telegraph" then
        local duration = math.max(0.001, spec.attack.telegraph)
        local progress = 1 - Clamp(enemy.stateTimer / duration, 0, 1)
        scaleX = 1 + progress * 0.14
        scaleY = 1 - progress * 0.12
    elseif enemy.state == "dash" then
        scaleX = 0.91
        scaleY = 1.14
    elseif enemy.state == "recovery" then
        local duration = math.max(0.001, spec.attack.recovery)
        local progress = Clamp(enemy.stateTimer / duration, 0, 1)
        scaleX = 1 + progress * 0.1
        scaleY = 1 - progress * 0.08
    end

    return scaleX, scaleY
end

local function DrawSpriteSoot(ctx, x, y, enemy, time, scale)
    local displayHeight = GetSootSpriteHeight(scale)
    local displayWidth = displayHeight * sootImageWidth / sootImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight
    local scaleX, scaleY = GetSootSquashStretch(enemy, time)
    -- The source sprite faces left, so only right-facing soot needs mirroring.
    local flip = enemy.facing == "right" and -1 or 1

    nvgSave(ctx)
    nvgTranslate(ctx, x, y)
    nvgScale(ctx, flip * scaleX, scaleY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, sootImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetBlueSwarmSpriteHeight(scale)
    return 52 * scale
end

local function DrawSpriteBlueSwarm(ctx, x, y, enemy, time, scale)
    local displayHeight = GetBlueSwarmSpriteHeight(scale)
    local displayWidth = displayHeight * blueSwarmImageWidth / blueSwarmImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 4 * scale
    local sway = math.sin(time * 11 + enemy.id * 0.83)

    if enemy.state == "telegraph" then
        local attack = EnemyConfig.blue_swarm.attack
        local progress = 1 - Clamp(enemy.stateTimer / attack.telegraph, 0, 1)
        local glowRadius = math.max(displayWidth, displayHeight) * (0.68 + progress * 0.32)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y - displayHeight * 0.52, glowRadius)
        nvgFillPaint(ctx, nvgRadialGradient(ctx, x, y - displayHeight * 0.52, glowRadius * 0.18, glowRadius,
            nvgRGBA(54, 222, 255, math.floor(75 + progress * 150)), nvgRGBA(54, 222, 255, 0)))
        nvgFill(ctx)
    end

    nvgSave(ctx)
    nvgTranslate(ctx, x + sway * 0.6 * scale, y + math.cos(time * 9 + enemy.id) * 0.35 * scale)
    nvgScale(ctx, 1 + sway * 0.022, 1 - sway * 0.018)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, blueSwarmImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetShadowWraithSpriteHeight(scale)
    return 54 * scale
end

local function DrawSpriteShadowWraith(ctx, x, y, enemy, time, scale)
    local displayHeight = GetShadowWraithSpriteHeight(scale)
    local displayWidth = displayHeight * shadowWraithImageWidth / shadowWraithImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 2 * scale
    local speed = math.sqrt(enemy.vx * enemy.vx + enemy.vy * enemy.vy)
    local motion = Clamp(speed / math.max(0.001, EnemyConfig.shadow_wraith.moveSpeed), 0, 1)
    local wave = math.sin(time * (4.2 + motion * 10) + enemy.id * 0.71)

    if motion > 0.01 then
        for index = 1, 2 do
            local offset = wave * index * 1.2 * scale
            nvgSave(ctx)
            nvgTranslate(ctx, x - offset, y + index * 0.25 * scale)
            nvgBeginPath(ctx)
            nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
            nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0,
                shadowWraithImageHandle, 0.09 * motion))
            nvgFill(ctx)
            nvgRestore(ctx)
        end
    end

    nvgSave(ctx)
    nvgTranslate(ctx, x + wave * (0.5 + motion * 1.1) * scale, y)
    nvgScale(ctx, 1 + wave * (0.012 + motion * 0.025), 1 - wave * (0.01 + motion * 0.018))
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, shadowWraithImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetHardSlimeSpriteHeight(scale)
    return 42 * scale
end

local function DrawSpriteHardSlime(ctx, x, y, enemy, time, scale)
    local displayHeight = GetHardSlimeSpriteHeight(scale)
    local displayWidth = displayHeight * hardSlimeImageWidth / hardSlimeImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 3 * scale
    local wobble = math.sin(time * 5.2 + enemy.id * 0.57)
    local scaleX = 1 + wobble * 0.025
    local scaleY = 1 - wobble * 0.02

    if enemy.state == "telegraph" then
        local attack = EnemyConfig.sap.attack
        local progress = 1 - Clamp(enemy.stateTimer / attack.telegraph, 0, 1)
        scaleX = scaleX + progress * 0.10
        scaleY = scaleY - progress * 0.08
    elseif enemy.state == "active" then
        scaleX = scaleX + 0.055
        scaleY = scaleY - 0.045
    end

    local pivotY = drawY + displayHeight
    nvgSave(ctx)
    nvgTranslate(ctx, x, y)
    nvgTranslate(ctx, 0, pivotY)
    nvgScale(ctx, scaleX, scaleY)
    nvgTranslate(ctx, 0, -pivotY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, hardSlimeImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetTreeWraithSpriteHeight(scale)
    return 62 * scale
end

local function DrawTreeRootSlam(ctx, x, y, enemy, time, scale)
    if enemy.state ~= "telegraph" and enemy.state ~= "active" then
        return
    end

    local attack = EnemyConfig.tree.attack
    local progress = enemy.state == "active" and 1
        or 1 - Clamp(enemy.stateTimer / math.max(0.001, attack.telegraph), 0, 1)
    local sourceY = y - 43 * scale
    local groundY = y + 3 * scale
    local reach = 34 * scale

    for _, direction in ipairs({ -1, 1 }) do
        local directionX = (enemy.attackX or 1) * direction
        local directionY = (enemy.attackY or 0) * direction
        local impactX = x + directionX * reach
        local impactY = groundY + directionY * reach * 0.2
        local tipY = sourceY + (impactY - sourceY) * progress

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x + directionX * 4 * scale, sourceY)
        nvgBezierTo(ctx,
            x + directionX * 15 * scale, sourceY + 12 * scale,
            impactX - directionX * 9 * scale, tipY - 15 * scale,
            impactX, tipY)
        nvgStrokeWidth(ctx, math.max(2, 6 * scale))
        StrokeColor(ctx, { 8, 7, 14 }, math.floor(135 + progress * 110))
        nvgStroke(ctx)

        if enemy.state == "active" then
            nvgBeginPath(ctx)
            nvgEllipse(ctx, impactX, impactY, 13 * scale, 4 * scale)
            nvgFillPaint(ctx, nvgRadialGradient(ctx, impactX, impactY, scale, 15 * scale,
                nvgRGBA(26, 18, 40, 190), nvgRGBA(8, 7, 14, 0)))
            nvgFill(ctx)
        end
    end
end

local function DrawSpriteTreeWraith(ctx, x, y, enemy, time, scale)
    local displayHeight = GetTreeWraithSpriteHeight(scale)
    local displayWidth = displayHeight * treeWraithImage.width / treeWraithImage.height
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 4 * scale
    local sway = math.sin(time * 3.4 + enemy.id * 0.61)
    local scaleX = 1 + sway * 0.018
    local scaleY = 1 - sway * 0.014

    if enemy.state == "telegraph" then
        local progress = 1 - Clamp(enemy.stateTimer / EnemyConfig.tree.attack.telegraph, 0, 1)
        scaleX = scaleX + progress * 0.06
        scaleY = scaleY - progress * 0.04
    end

    nvgSave(ctx)
    nvgTranslate(ctx, x, y)
    nvgScale(ctx, scaleX, scaleY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, treeWraithImage.handle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetStoneSpriteHeight(scale)
    return 44 * scale
end

local function DrawSpriteStone(ctx, x, y, enemy, time, scale)
    local displayHeight = GetStoneSpriteHeight(scale)
    local displayWidth = displayHeight * stoneImageWidth / stoneImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 2 * scale
    local motionX = enemy.state == "dash" and enemy.dashX or enemy.vx
    local direction = motionX < -0.001 and -1 or 1
    local speed = math.sqrt(enemy.vx * enemy.vx + enemy.vy * enemy.vy)
    local rollSpeed = enemy.state == "dash" and 20 or math.min(5, speed * 20)
    local centerY = drawY + displayHeight * 0.5

    nvgSave(ctx)
    nvgTranslate(ctx, x, y)
    nvgTranslate(ctx, 0, centerY)
    nvgRotate(ctx, (time * rollSpeed + enemy.id * 0.37) * direction)
    nvgTranslate(ctx, 0, -centerY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, stoneImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetMushroomSpriteHeight(scale)
    return 38 * scale
end

local function DrawSpriteMushroom(ctx, x, y, enemy, time, scale)
    local displayHeight = GetMushroomSpriteHeight(scale)
    local displayWidth = displayHeight * mushroomImageWidth / mushroomImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 2 * scale
    local scaleX = 1 + math.sin(time * 2.6 + enemy.id * 0.41) * 0.012
    local scaleY = 1 - math.sin(time * 2.6 + enemy.id * 0.41) * 0.012

    local pivotY = drawY + displayHeight
    nvgSave(ctx)
    nvgTranslate(ctx, x, y)
    nvgTranslate(ctx, 0, pivotY)
    nvgScale(ctx, scaleX, scaleY)
    nvgTranslate(ctx, 0, -pivotY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, mushroomImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetDandelionSpriteHeight(scale)
    return 42 * scale
end

local function DrawSpriteDandelion(ctx, x, y, enemy, time, scale)
    local displayHeight = GetDandelionSpriteHeight(scale)
    local displayWidth = displayHeight * dandelionImageWidth / dandelionImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 2 * scale
    local shakeX, shakeY, rotation = 0, 0, 0

    local pivotY = drawY + displayHeight
    nvgSave(ctx)
    nvgTranslate(ctx, x + shakeX, y + shakeY)
    nvgTranslate(ctx, 0, pivotY)
    nvgRotate(ctx, rotation)
    nvgTranslate(ctx, 0, -pivotY)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, dandelionImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function GetPurpleOrbSpriteHeight(scale)
    return 44 * scale
end

local function DrawSpritePurpleOrb(ctx, x, y, enemy, time, scale)
    local displayHeight = GetPurpleOrbSpriteHeight(scale)
    local displayWidth = displayHeight * purpleOrbImageWidth / purpleOrbImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight + 6 * scale
    local shakeX, shakeY, rotation = 0, 0, 0

    nvgSave(ctx)
    nvgTranslate(ctx, x + shakeX, y + shakeY)
    nvgRotate(ctx, rotation)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, purpleOrbImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function DrawBlueSwarm(ctx, x, y, size, scale, time, color, secondary)
    local centerY = y - size * 0.58
    for index = 1, 12 do
        local angle = index * 2.39 + time * (1.3 + (index % 3) * 0.17)
        local orbit = size * (0.18 + (index % 4) * 0.08)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x + math.cos(angle) * orbit, centerY + math.sin(angle * 1.3) * orbit * 0.62,
            (1.6 + (index % 3) * 0.7) * scale)
        Color(ctx, index % 2 == 0 and secondary or color, 235)
        nvgFill(ctx)
    end
    DrawEyes(ctx, x, centerY, scale, size * 0.1, { 225, 248, 255 })
end

local function DrawTree(ctx, x, y, size, scale, color, secondary)
    local centerY = y - size * 0.52
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size * 0.2, centerY - size * 0.02, size * 0.4, size * 0.64, size * 0.12)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, secondary, 240)
    nvgStroke(ctx)
    for side = -1, 1, 2 do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x + side * size * 0.12, centerY + size * 0.17)
        nvgLineTo(ctx, x + side * size * 0.5, centerY - size * 0.2)
        nvgLineTo(ctx, x + side * size * 0.66, centerY - size * 0.08)
        nvgStrokeWidth(ctx, 2.4 * scale)
        StrokeColor(ctx, color, 245)
        nvgStroke(ctx)
    end
    DrawEyes(ctx, x, centerY + size * 0.12, scale, size * 0.11, { 188, 130, 232 })
end

local function DrawSap(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.55
    local shine = nvgRadialGradient(ctx, x - size * 0.17, centerY - size * 0.18, size * 0.04, size * 0.72,
        nvgRGBA(244, 255, 250, 230), nvgRGBA(color[1], color[2], color[3], 205))
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, centerY, size * 0.53, size * 0.42)
    nvgFillPaint(ctx, shine)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 240)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x - size * 0.12, centerY - size * 0.18)
    nvgLineTo(ctx, x + size * 0.03, centerY + size * 0.02)
    nvgLineTo(ctx, x - size * 0.02, centerY + size * 0.2)
    nvgStrokeWidth(ctx, 1.35 * scale)
    StrokeColor(ctx, secondary, 185)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY - size * 0.03, scale, size * 0.12)
end

local function DrawGhost(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.58
    local glow = nvgRadialGradient(ctx, x, centerY, size * 0.28, size * 1.18,
        nvgRGBA(outline[1], outline[2], outline[3], 120), nvgRGBA(outline[1], outline[2], outline[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 1.18)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x - size * 0.45, centerY + size * 0.38)
    nvgBezierTo(ctx, x - size * 0.64, centerY, x - size * 0.38, centerY - size * 0.55, x, centerY - size * 0.48)
    nvgBezierTo(ctx, x + size * 0.48, centerY - size * 0.62, x + size * 0.62, centerY + size * 0.04, x + size * 0.42, centerY + size * 0.42)
    nvgBezierTo(ctx, x + size * 0.16, centerY + size * 0.18, x - size * 0.08, centerY + size * 0.65, x - size * 0.45, centerY + size * 0.38)
    Color(ctx, color, 174)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2.2 * scale)
    StrokeColor(ctx, outline, 255)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY - size * 0.03, scale, size * 0.12, secondary)
end

local function DrawStone(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.52
    nvgBeginPath(ctx)
    for index = 0, 5 do
        local angle = math.pi * 0.166 + index * math.pi * 2 / 6
        local px = x + math.cos(angle) * size * 0.48
        local py = centerY + math.sin(angle) * size * 0.45
        if index == 0 then nvgMoveTo(ctx, px, py) else nvgLineTo(ctx, px, py) end
    end
    nvgClosePath(ctx)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 255)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x - size * 0.26, centerY - size * 0.08)
    nvgLineTo(ctx, x + size * 0.24, centerY - size * 0.26)
    nvgStrokeWidth(ctx, 1.3 * scale)
    StrokeColor(ctx, secondary, 170)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY + size * 0.04, scale, size * 0.13, { 255, 255, 255 })
end

local function DrawMushroom(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.54
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size * 0.14, centerY, size * 0.28, size * 0.43, size * 0.08)
    Color(ctx, secondary, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, centerY - size * 0.06, size * 0.55, size * 0.28)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 255)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY + size * 0.17, scale, size * 0.1)
end

local function DrawDandelion(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.66
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, centerY + size * 0.18)
    nvgLineTo(ctx, x, y)
    nvgStrokeWidth(ctx, 2.2 * scale)
    StrokeColor(ctx, secondary, 235)
    nvgStroke(ctx)
    for index = 0, 11 do
        local angle = index * math.pi * 2 / 12
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x, centerY)
        nvgLineTo(ctx, x + math.cos(angle) * size * 0.48, centerY + math.sin(angle) * size * 0.42)
        nvgStrokeWidth(ctx, 1.1 * scale)
        StrokeColor(ctx, secondary, 200)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 0.26)
    Color(ctx, color, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 1.7 * scale)
    StrokeColor(ctx, outline, 250)
    nvgStroke(ctx)
    DrawEyes(ctx, x, centerY, scale, size * 0.08)
end

local function DrawOrb(ctx, x, y, size, scale, color, secondary, outline)
    local centerY = y - size * 0.56
    local glow = nvgRadialGradient(ctx, x, centerY, size * 0.2, size * 1.35,
        nvgRGBA(secondary[1], secondary[2], secondary[3], 165), nvgRGBA(secondary[1], secondary[2], secondary[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 1.25)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, centerY, size * 0.43)
    Color(ctx, color, 245)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2 * scale)
    StrokeColor(ctx, outline, 250)
    nvgStroke(ctx)
    for index = 0, 7 do
        local angle = index * math.pi * 2 / 8
        nvgBeginPath(ctx)
        nvgCircle(ctx, x + math.cos(angle) * size * 0.67, centerY + math.sin(angle) * size * 0.58, 1.4 * scale)
        Color(ctx, secondary, 210)
        nvgFill(ctx)
    end
end

local function DrawSpriteToxicMoss(ctx, x, y, enemy, time, scale)
    local displayHeight = 38 * scale
    local displayWidth = displayHeight * toxicMossImageWidth / toxicMossImageHeight
    local drawX = -displayWidth * 0.5
    local drawY = -displayHeight * 0.6
    local pulse = math.sin(time * 5.2 + enemy.id * 0.91)

    nvgSave(ctx)
    nvgTranslate(ctx, x + pulse * 0.45 * scale, y + math.cos(time * 4.4 + enemy.id) * 0.22 * scale)
    nvgScale(ctx, 1 + pulse * 0.012, 1 - pulse * 0.01)
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, toxicMossImageHandle, 1.0))
    nvgFill(ctx)
    nvgRestore(ctx)
end

local function DrawMoss(ctx, x, y, size, scale, color, secondary, outline)
    nvgBeginPath(ctx)
    nvgEllipse(ctx, x, y - size * 0.08, size * 0.7, size * 0.24)
    Color(ctx, outline, 200)
    nvgFill(ctx)
    for index = 0, 4 do
        local angle = index * math.pi * 2 / 5
        nvgBeginPath(ctx)
        nvgEllipse(ctx, x + math.cos(angle) * size * 0.35, y - size * 0.08 + math.sin(angle) * size * 0.12,
            size * 0.28, size * 0.13)
        Color(ctx, index % 2 == 0 and secondary or color, 235)
        nvgFill(ctx)
    end
end

local function DrawEnemy(ctx, width, height, enemy, player, time)
    local x, y, scale = Renderer.WorldToScreen(width, height, enemy.x, enemy.y)
    DrawEnemyMotionTrail(ctx, width, height, enemy)
    DrawEnemyTelegraph(ctx, width, height, enemy, player)
    scale = scale * EnemyConfig.sizeMultiplier
    local spec = EnemyConfig[enemy.kind]
    local visual = spec.visual
    local size = 24 * scale
    local pulse = math.sin(time * 7 + enemy.id) * 1.2 * scale

    if enemy.kind ~= "toxic_moss" then
        DrawShadow(ctx, x, y, scale, size * 0.68, 125)
    end

    if enemy.kind == "soot" then
        if sootImageHandle ~= nil and sootImageHandle > 0 then
            DrawSpriteSoot(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawSoot(ctx, x, y + pulse, size, scale, time, visual.primary, visual.secondary)
        end
    elseif enemy.kind == "blue_swarm" then
        if blueSwarmImageHandle ~= nil and blueSwarmImageHandle > 0 then
            DrawSpriteBlueSwarm(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawBlueSwarm(ctx, x, y + pulse, size, scale, time, visual.primary, visual.secondary)
        end
    elseif enemy.kind == "tree" then
        DrawTreeRootSlam(ctx, x, y + pulse, enemy, time, scale)
        if treeWraithImage.handle ~= nil and treeWraithImage.handle > 0 then
            DrawSpriteTreeWraith(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawTree(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary)
        end
    elseif enemy.kind == "sap" then
        if hardSlimeImageHandle ~= nil and hardSlimeImageHandle > 0 then
            DrawSpriteHardSlime(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawSap(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
        end
    elseif enemy.kind == "shadow_wraith" then
        if shadowWraithImageHandle ~= nil and shadowWraithImageHandle > 0 then
            DrawSpriteShadowWraith(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawGhost(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
        end
    elseif enemy.kind == "stone" then
        if stoneImageHandle ~= nil and stoneImageHandle > 0 then
            DrawSpriteStone(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawStone(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
        end
    elseif enemy.kind == "mushroom" then
        if mushroomImageHandle ~= nil and mushroomImageHandle > 0 then
            DrawSpriteMushroom(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawMushroom(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
        end
    elseif enemy.kind == "dandelion" then
        if dandelionImageHandle ~= nil and dandelionImageHandle > 0 then
            DrawSpriteDandelion(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawDandelion(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
        end
    elseif enemy.kind == "purple_orb" then
        if purpleOrbImageHandle ~= nil and purpleOrbImageHandle > 0 then
            DrawSpritePurpleOrb(ctx, x, y + pulse, enemy, time, scale)
        else
            DrawOrb(ctx, x, y + pulse, size, scale, visual.primary, visual.secondary, visual.outline)
        end
    elseif enemy.kind == "toxic_moss" then
        if toxicMossImageHandle ~= nil and toxicMossImageHandle > 0 then
            DrawSpriteToxicMoss(ctx, x, y, enemy, time, scale)
        else
            DrawMoss(ctx, x, y, size, scale, visual.primary, visual.secondary, visual.outline)
        end
    else
        DrawMoss(ctx, x, y, size, scale, visual.primary, visual.secondary, visual.outline)
    end

    -- Use one high-contrast health-bar treatment for every normal enemy.
    local healthWidth = size * 1.32
    local healthHeight = 6 * scale
    local healthBorder = math.max(1, 1.25 * scale)
    local healthY = y - size * 1.18
    if enemy.kind == "soot" and sootImageHandle ~= nil and sootImageHandle > 0 then
        healthY = y - GetSootSpriteHeight(scale) - 5 * scale
    elseif enemy.kind == "blue_swarm" and blueSwarmImageHandle ~= nil and blueSwarmImageHandle > 0 then
        healthY = y - GetBlueSwarmSpriteHeight(scale) - 3 * scale
    elseif enemy.kind == "shadow_wraith" and shadowWraithImageHandle ~= nil and shadowWraithImageHandle > 0 then
        healthY = y - GetShadowWraithSpriteHeight(scale) - 2 * scale
    elseif enemy.kind == "sap" and hardSlimeImageHandle ~= nil and hardSlimeImageHandle > 0 then
        healthY = y - GetHardSlimeSpriteHeight(scale) - 4 * scale
    elseif enemy.kind == "tree" and treeWraithImage.handle ~= nil and treeWraithImage.handle > 0 then
        healthY = y - GetTreeWraithSpriteHeight(scale) - 3 * scale
    elseif enemy.kind == "stone" and stoneImageHandle ~= nil and stoneImageHandle > 0 then
        healthY = y - GetStoneSpriteHeight(scale) - 4 * scale
    elseif enemy.kind == "mushroom" and mushroomImageHandle ~= nil and mushroomImageHandle > 0 then
        healthY = y - GetMushroomSpriteHeight(scale) - 4 * scale
    elseif enemy.kind == "dandelion" and dandelionImageHandle ~= nil and dandelionImageHandle > 0 then
        healthY = y - GetDandelionSpriteHeight(scale) - 4 * scale
    elseif enemy.kind == "purple_orb" and purpleOrbImageHandle ~= nil and purpleOrbImageHandle > 0 then
        healthY = y - GetPurpleOrbSpriteHeight(scale) - 4 * scale
    end
    local healthRatio = math.max(0, enemy.hp / math.max(0.001, enemy.maxHp))
    local innerWidth = healthWidth - healthBorder * 2
    local innerHeight = math.max(1, healthHeight - healthBorder * 2)
    local innerX = x - healthWidth * 0.5 + healthBorder
    local innerY = healthY + healthBorder

    -- Dark frame, red missing-health base, then the classic green current-health fill.
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - healthWidth * 0.5, healthY, healthWidth, healthHeight, healthHeight * 0.5)
    Color(ctx, { 20, 20, 20 }, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, innerX, innerY, innerWidth, innerHeight, innerHeight * 0.35)
    Color(ctx, { 184, 45, 45 }, 255)
    nvgFill(ctx)
    local fillWidth = math.max(0, innerWidth * healthRatio)
    if fillWidth > 0 then
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, innerX, innerY, fillWidth, innerHeight, innerHeight * 0.35)
        Color(ctx, { 71, 205, 70 }, 255)
        nvgFill(ctx)
    end
end

local function DrawProjectileSprite(ctx, x, y, radius, imageHandle, imageWidth, imageHeight)
    if imageHandle == nil or imageHandle <= 0 or imageWidth <= 0 or imageHeight <= 0 then
        return false
    end

    local displayWidth = radius * 4.0
    local displayHeight = displayWidth * imageHeight / imageWidth
    local drawX = x - displayWidth * 0.5
    local drawY = y - displayHeight * 0.5
    nvgBeginPath(ctx)
    nvgRect(ctx, drawX, drawY, displayWidth, displayHeight)
    nvgFillPaint(ctx, nvgImagePattern(ctx, drawX, drawY, displayWidth, displayHeight, 0, imageHandle, 1.0))
    nvgFill(ctx)
    return true
end

local function DrawProjectile(ctx, width, height, projectile, combo)
    local x, y, scale = Renderer.WorldToScreen(width, height, projectile.x, projectile.y)
    ---@type number[]
    local color = projectile.owner == "player" and { 125, 238, 255 } or { 255, 135, 205 }
    if projectile.crystalSplit then
        color = { 247, 171, 255 }
    elseif projectile.crystalGuard then
        color = { 150, 135, 255 }
    end

    if projectile.owner == "enemy" and projectile.style == "spore" then
        color = { 208, 166, 238 }
    elseif projectile.owner == "enemy" and projectile.style == "seed" then
        color = { 192, 175, 220 }
    end
    if projectile.reflected and combo ~= nil and combo.tier > 0 then
        local tierColors = {
            { 105, 225, 221 },
            { 245, 195, 105 },
            { 255, 126, 161 },
        }
        local tierColor = tierColors[math.min(combo.tier, #tierColors)]
        if tierColor ~= nil then
            color = tierColor
        end
    end
    local radius = (5 + projectile.radius * 80) * scale
    if projectile.style == "spore" then
        radius = radius * 1.22
    elseif projectile.style == "seed" then
        radius = radius * 0.82
    end
    local speed = math.sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy)
    local directionX, directionY = 0, 0
    if speed > 0.0001 then
        directionX, directionY = projectile.vx / speed, projectile.vy / speed
        local tailLength = radius * (projectile.reflected and 5.4 or 3.2)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x - directionX * tailLength, y - directionY * tailLength)
        nvgLineTo(ctx, x, y)
        nvgStrokeWidth(ctx, projectile.reflected and radius * 0.9 or radius * 0.55)
        StrokeColor(ctx, color, projectile.reflected and 130 or 80)
        nvgStroke(ctx)
    end

    if projectile.reflected then
        local glow = nvgRadialGradient(ctx, x, y, radius * 0.18, radius * 3.3,
            nvgRGBA(color[1], color[2], color[3], 185), nvgRGBA(color[1], color[2], color[3], 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius * 3.3)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)
    end

    if projectile.style == "spore" and not projectile.reflected then
        local sporeGlow = nvgRadialGradient(ctx, x, y, radius * 0.2, radius * 2.5,
            nvgRGBA(255, 255, 255, 170), nvgRGBA(255, 255, 255, 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius * 2.5)
        nvgFillPaint(ctx, sporeGlow)
        nvgFill(ctx)
    end
    local sprite = projectileSprites[projectile.style]
    if not DrawProjectileSprite(ctx, x, y, radius, sprite and sprite.handle or 0,
            sprite and sprite.width or 1, sprite and sprite.height or 1) then
        nvgBeginPath(ctx)
        if projectile.style == "seed" and not projectile.reflected then
            nvgEllipse(ctx, x, y, radius * 0.72, radius)
        else
            nvgCircle(ctx, x, y, radius)
        end
        Color(ctx, color, 255)
        nvgFill(ctx)
    end

    if projectile.reflected then
        nvgBeginPath(ctx)
        nvgCircle(ctx, x - directionX * radius * 0.14, y - directionY * radius * 0.14, radius * 0.42)
        Color(ctx, { 255, 252, 236 }, 245)
        nvgFill(ctx)
    end
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius * 2.05)
    nvgStrokeWidth(ctx, 1.4 * scale)
    StrokeColor(ctx, color, 100)
    nvgStroke(ctx)
end

local function DrawSpawnRoomGuide(ctx, width, height, game)
    if game.room == nil or not game.room.isBirthRoom or spawnRoomGuideImageHandle <= 0 then
        return
    end

    local guideAlpha = Clamp(game.spawnGuideAlpha or 0, 0, 1)
    if guideAlpha <= 0 then
        return
    end

    local centerX, centerY, scale = Renderer.WorldToScreen(width, height, 0.5, 0.47)
    local guideWidth = 236 * scale
    local guideHeight = guideWidth * spawnRoomGuideImageHeight / spawnRoomGuideImageWidth
    local guideX = centerX - guideWidth * 0.5
    local guideY = centerY - guideHeight * 0.5
    local pulse = 0.9 + 0.1 * math.sin(game.time * 2.4)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, guideX - 10 * scale, guideY - 8 * scale,
        guideWidth + 20 * scale, guideHeight + 16 * scale, 12 * scale)
    nvgFillPaint(ctx, nvgBoxGradient(ctx, guideX, guideY, guideWidth, guideHeight, 10 * scale, 18 * scale,
        nvgRGBA(95, 169, 190, math.floor(24 * guideAlpha * pulse)), nvgRGBA(69, 44, 88, 0)))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRect(ctx, guideX, guideY, guideWidth, guideHeight)
    nvgFillPaint(ctx, nvgImagePatternTinted(ctx, guideX, guideY, guideWidth, guideHeight, 0,
        spawnRoomGuideImageHandle, nvgRGBA(255, 246, 221, math.floor(214 * guideAlpha * pulse))))
    nvgFill(ctx)
end

local function DrawSpawnRoomParryGuide(ctx, width, height, game)
    if game.room == nil or not game.room.isBirthRoom or spawnRoomParryGuideImageHandle <= 0 then
        return
    end

    local guideAlpha = Clamp(game.spawnParryGuideAlpha or 0, 0, 1)
    if guideAlpha <= 0 then
        return
    end

    local centerX, centerY, scale = Renderer.WorldToScreen(width, height, 0.5, 0.47)
    local guideHeight = 162 * scale
    local guideWidth = guideHeight * spawnRoomParryGuideImageWidth / spawnRoomParryGuideImageHeight
    local guideX = centerX - guideWidth * 0.5
    local guideY = centerY - guideHeight * 0.5
    local pulse = 0.9 + 0.1 * math.sin(game.time * 3.0)

    nvgBeginPath(ctx)
    nvgRect(ctx, guideX, guideY, guideWidth, guideHeight)
    nvgFillPaint(ctx, nvgImagePatternTinted(ctx, guideX, guideY, guideWidth, guideHeight, 0,
        spawnRoomParryGuideImageHandle, nvgRGBA(235, 250, 250, math.floor(225 * guideAlpha * pulse))))
    nvgFill(ctx)
end

local function DrawChest(ctx, width, height, chest)
    local x, y, scale = Renderer.WorldToScreen(width, height, chest.x, chest.y)
    local visualLift = 0
    local sizeMultiplier = 1
    local glowAlpha = 45
    local shadowAlpha = 120

    if chest.state == "dropping" then
        local flightProgress = Clamp((chest.dropElapsed or 0) / ChestConfig.dropDuration, 0, 1)
        if flightProgress < 1 then
            visualLift = math.sin(flightProgress * math.pi) * ChestConfig.dropArcHeight * 190 * scale
            sizeMultiplier = 0.78 + flightProgress * 0.22
            shadowAlpha = math.floor(35 + flightProgress * 80)
        else
            local bounceProgress = Clamp(
                ((chest.dropElapsed or 0) - ChestConfig.dropDuration) / ChestConfig.bounceDuration, 0, 1)
            if bounceProgress < 0.62 then
                visualLift = math.sin(bounceProgress / 0.62 * math.pi) * ChestConfig.firstBounceHeight * 190 * scale
            else
                visualLift = math.sin((bounceProgress - 0.62) / 0.38 * math.pi)
                    * ChestConfig.secondBounceHeight * 190 * scale
            end
            glowAlpha = math.floor(55 + (1 - bounceProgress) * 65)
        end
    elseif chest.state == "idle" then
        local pulse = 0.78 + 0.22 * math.sin(chest.bobTime * 0.9)
        y = y + math.sin(chest.bobTime) * 4 * scale
        glowAlpha = math.floor(70 * pulse)
    elseif chest.state == "collecting" then
        local collectProgress = Clamp((chest.collectElapsed or 0) / ChestConfig.collectDuration, 0, 1)
        sizeMultiplier = 1 - collectProgress * 0.28
        glowAlpha = math.floor(125 * (1 - collectProgress))
        shadowAlpha = math.floor(100 * (1 - collectProgress))

        local trailX = chest.collectStartX or chest.x
        local trailY = chest.collectStartY or chest.y
        local trailScreenX, trailScreenY = Renderer.WorldToScreen(width, height, trailX, trailY)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, trailScreenX, trailScreenY)
        nvgLineTo(ctx, x, y)
        nvgStrokeWidth(ctx, 3 * scale)
        nvgStrokeColor(ctx, nvgRGBA(255, 222, 118, math.floor(140 * (1 - collectProgress))))
        nvgStroke(ctx)
    end

    y = y - visualLift
    local size = 14 * scale * sizeMultiplier
    DrawShadow(ctx, x, y + visualLift, scale * sizeMultiplier, 14, shadowAlpha)

    if chest.landed then
        local landingProgress = Clamp(((chest.dropElapsed or 0) - ChestConfig.dropDuration) / 0.22, 0, 1)
        if landingProgress < 1 then
            local ringRadius = (12 + landingProgress * 28) * scale
            nvgBeginPath(ctx)
            nvgEllipse(ctx, x, y + size * 0.4, ringRadius, ringRadius * 0.38)
            nvgStrokeWidth(ctx, 1.6 * scale)
            nvgStrokeColor(ctx, nvgRGBA(255, 222, 112, math.floor(190 * (1 - landingProgress))))
            nvgStroke(ctx)
        end
    end

    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y - size * 0.3, size * (chest.state == "idle" and 1.8 or 1.5))
    nvgFillColor(ctx, nvgRGBA(255, 212, 95, glowAlpha))
    nvgFill(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size, y - size * 0.78, size * 2, size * 1.2, 3 * scale)
    Color(ctx, { 230, 166, 58 }, 255)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 1.8 * scale)
    StrokeColor(ctx, { 255, 238, 150 }, 255)
    nvgStroke(ctx)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - size, y - size * 1.1, size * 2, size * 0.48, 3 * scale)
    Color(ctx, { 255, 205, 85 }, 255)
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRect(ctx, x - 2 * scale, y - size * 1.08, 4 * scale, size * 1.45)
    Color(ctx, { 95, 57, 35 }, 255)
    nvgFill(ctx)
end

local function DrawParryCone(ctx, width, height, player)
    if player.parryTimer <= 0 then
        return
    end

    local directionX = player.parryDirectionX or (player.facing == "left" and -1 or 1)
    local directionY = player.parryDirectionY or 0
    local facingAngle = math.atan(directionY, directionX)
    local halfAngle = math.acos(Clamp(player.parryHalfAngleCos, -1, 1))
    local x, y = Renderer.WorldToScreen(width, height, player.x, player.y)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y)
    for step = 0, 12 do
        local angle = facingAngle - halfAngle + (halfAngle * 2 * step / 12)
        local worldX = player.x + math.cos(angle) * PlayerConfig.parryRange
        local worldY = player.y + math.sin(angle) * PlayerConfig.parryRange
        local pointX, pointY = Renderer.WorldToScreen(width, height, worldX, worldY)
        nvgLineTo(ctx, pointX, pointY)
    end
    nvgClosePath(ctx)
    Color(ctx, { 110, 235, 255 }, 70)
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 2)
    StrokeColor(ctx, { 190, 250, 255 }, 220)
    nvgStroke(ctx)
end

local function DrawParticles(ctx, width, height, particles)
    for _, particle in ipairs(particles) do
        local x, y, scale = Renderer.WorldToScreen(width, height, particle.x, particle.y)
        local alpha = math.floor(255 * Clamp(particle.life / particle.maxLife, 0, 1))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, 2.2 * scale)
        Color(ctx, particle.color, alpha)
        nvgFill(ctx)
    end
end

local function DrawBurstArc(ctx, x, y, radius, facingAngle, halfAngle, color, alpha, stroke)
    nvgBeginPath(ctx)
    for step = 0, 12 do
        local angle = facingAngle - halfAngle + (halfAngle * 2 * step / 12)
        local pointX = x + math.cos(angle) * radius
        local pointY = y + math.sin(angle) * radius
        if step == 0 then
            nvgMoveTo(ctx, pointX, pointY)
        else
            nvgLineTo(ctx, pointX, pointY)
        end
    end
    nvgStrokeWidth(ctx, stroke)
    StrokeColor(ctx, color, alpha)
    nvgStroke(ctx)
end

local function DrawParryGuardBurst(ctx, x, y, scale, burst, progress)
    local radius = Lerp(burst.startRadius, burst.endRadius, math.sqrt(progress)) * scale
    local alpha = math.floor(230 * (1 - progress) * (1 - progress))
    local facingAngle = math.atan(burst.directionY, burst.directionX)
    local halfAngle = math.rad((burst.arcDegrees or 120) * 0.5)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y)
    for step = 0, 14 do
        local angle = facingAngle - halfAngle + (halfAngle * 2 * step / 14)
        nvgLineTo(ctx, x + math.cos(angle) * radius, y + math.sin(angle) * radius)
    end
    nvgClosePath(ctx)
    Color(ctx, burst.color, math.floor(alpha * 0.18))
    nvgFill(ctx)
    DrawBurstArc(ctx, x, y, radius, facingAngle, halfAngle, burst.color, alpha,
        math.max(1, burst.stroke * scale))

    for index = -1, 1 do
        local rayAngle = facingAngle + index * halfAngle * 0.62
        local rayStart = radius * 0.28
        local rayEnd = radius * (0.78 + (index + 1) * 0.07)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x + math.cos(rayAngle) * rayStart, y + math.sin(rayAngle) * rayStart)
        nvgLineTo(ctx, x + math.cos(rayAngle) * rayEnd, y + math.sin(rayAngle) * rayEnd)
        nvgStrokeWidth(ctx, math.max(1, burst.stroke * scale * 0.58))
        StrokeColor(ctx, { 232, 255, 255 }, math.floor(alpha * 0.78))
        nvgStroke(ctx)
    end
end

local function DrawParrySuccessBurst(ctx, x, y, scale, burst, progress)
    local radius = Lerp(burst.startRadius, burst.endRadius, math.sqrt(progress)) * scale
    local alpha = math.floor(250 * (1 - progress) * (1 - progress))
    local rayCount = burst.kind == "perfect_parry" and 8 or 6
    local coreRadius = radius * (burst.kind == "perfect_parry" and 0.34 or 0.26)
    local glow = nvgRadialGradient(ctx, x, y, coreRadius * 0.25, radius * 1.18,
        nvgRGBA(burst.color[1], burst.color[2], burst.color[3], math.floor(alpha * 0.55)),
        nvgRGBA(burst.color[1], burst.color[2], burst.color[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius * 1.18)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    local facingAngle = math.atan(burst.directionY, burst.directionX)
    for index = 1, rayCount do
        local angle = facingAngle + (index - 1) * math.pi * 2 / rayCount
        local startRadius = coreRadius * 0.65
        local endRadius = radius * (0.72 + (index % 2) * 0.16)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x + math.cos(angle) * startRadius, y + math.sin(angle) * startRadius)
        nvgLineTo(ctx, x + math.cos(angle) * endRadius, y + math.sin(angle) * endRadius)
        nvgStrokeWidth(ctx, math.max(1, burst.stroke * scale * (burst.kind == "perfect_parry" and 0.92 or 0.66)))
        StrokeColor(ctx, burst.color, alpha)
        nvgStroke(ctx)
    end
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, coreRadius)
    Color(ctx, { 255, 252, 236 }, math.floor(alpha * 0.92))
    nvgFill(ctx)
end

local function DrawWraithTouchBurst(ctx, width, height, x, y, scale, burst, progress)
    local radius = Lerp(burst.startRadius, burst.endRadius, math.sqrt(progress)) * scale
    local alpha = math.floor(235 * (1 - progress) * (1 - progress))
    local originX = x - burst.directionX * radius * 1.15
    local originY = y - burst.directionY * radius * 1.15
    if type(burst.originX) == "number" and type(burst.originY) == "number" then
        originX, originY = Renderer.WorldToScreen(width, height, burst.originX, burst.originY)
    end

    local tetherX = x - originX
    local tetherY = y - originY
    local tetherLength = math.sqrt(tetherX * tetherX + tetherY * tetherY)
    if tetherLength > 0.001 then
        local perpendicularX = -tetherY / tetherLength
        local perpendicularY = tetherX / tetherLength
        local bend = math.sin(progress * math.pi) * math.min(radius * 0.72, tetherLength * 0.18)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, originX, originY)
        nvgBezierTo(ctx,
            originX + tetherX * 0.28 + perpendicularX * bend, originY + tetherY * 0.28 + perpendicularY * bend,
            originX + tetherX * 0.72 - perpendicularX * bend, originY + tetherY * 0.72 - perpendicularY * bend,
            x, y)
        nvgStrokeWidth(ctx, math.max(1.2, burst.stroke * scale * 1.45))
        StrokeColor(ctx, burst.color, math.floor(alpha * 0.36))
        nvgStroke(ctx)
        nvgStrokeWidth(ctx, math.max(1, burst.stroke * scale * 0.5))
        StrokeColor(ctx, { 249, 255, 198 }, math.floor(alpha * 0.92))
        nvgStroke(ctx)
    end

    local glow = nvgRadialGradient(ctx, x, y, radius * 0.12, radius * 1.32,
        nvgRGBA(burst.color[1], burst.color[2], burst.color[3], math.floor(alpha * 0.48)),
        nvgRGBA(burst.color[1], burst.color[2], burst.color[3], 0))
    nvgBeginPath(ctx)
    nvgCircle(ctx, x, y, radius * 1.32)
    nvgFillPaint(ctx, glow)
    nvgFill(ctx)

    for index = 1, 4 do
        local angle = math.atan(burst.directionY, burst.directionX) + (index - 2.5) * 0.56
        local startRadius = radius * 0.26
        local endRadius = radius * (0.68 + (index % 2) * 0.13)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x + math.cos(angle) * startRadius, y + math.sin(angle) * startRadius)
        nvgLineTo(ctx, x + math.cos(angle) * endRadius, y + math.sin(angle) * endRadius)
        nvgStrokeWidth(ctx, math.max(1, burst.stroke * scale * 0.62))
        StrokeColor(ctx, burst.color, alpha)
        nvgStroke(ctx)
    end
end

local function DrawFeedbackWorld(ctx, width, height, feedback)
    if feedback == nil then
        return
    end

    for _, impact in ipairs(feedback.impacts) do
        local progress = 1 - Clamp(impact.life / math.max(0.001, impact.maxLife), 0, 1)
        local x, y, scale = Renderer.WorldToScreen(width, height, impact.x, impact.y)
        local radius = Lerp(impact.startRadius, impact.endRadius, math.sqrt(progress)) * scale
        local alpha = math.floor(225 * (1 - progress) * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius)
        nvgStrokeWidth(ctx, math.max(1, impact.stroke * scale * (1 - progress * 0.35)))
        StrokeColor(ctx, impact.color, alpha)
        nvgStroke(ctx)
    end

    for _, burst in ipairs(feedback.bursts or {}) do
        local progress = 1 - Clamp(burst.life / math.max(0.001, burst.maxLife), 0, 1)
        local x, y, scale = Renderer.WorldToScreen(width, height, burst.x, burst.y)
        if burst.kind == "parry_guard" then
            DrawParryGuardBurst(ctx, x, y, scale, burst, progress)
        elseif burst.kind == "parry_success" or burst.kind == "perfect_parry" then
            DrawParrySuccessBurst(ctx, x, y, scale, burst, progress)
        elseif burst.kind == "wraith_touch" then
            DrawWraithTouchBurst(ctx, width, height, x, y, scale, burst, progress)
        end
    end

    for _, shockwave in ipairs(feedback.shockwaves or {}) do
        local progress = 1 - Clamp(shockwave.life / math.max(0.001, shockwave.maxLife), 0, 1)
        local x, y, scale = Renderer.WorldToScreen(width, height, shockwave.x, shockwave.y)
        local radius = Lerp(shockwave.startRadius, shockwave.endRadius, math.sqrt(progress)) * scale
        local alpha = math.floor(200 * (1 - progress) * (1 - progress))
        local glow = nvgRadialGradient(ctx, x, y, radius * 0.20, radius * 1.35,
            nvgRGBA(shockwave.color[1], shockwave.color[2], shockwave.color[3], math.floor(alpha * 0.38)),
            nvgRGBA(shockwave.color[1], shockwave.color[2], shockwave.color[3], 0))
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius * 1.35)
        nvgFillPaint(ctx, glow)
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgCircle(ctx, x, y, radius)
        nvgStrokeWidth(ctx, math.max(1, shockwave.stroke * scale * (1 - progress * 0.25)))
        StrokeColor(ctx, shockwave.color, alpha)
        nvgStroke(ctx)
    end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, floatingText in ipairs(feedback.floatingTexts) do
        local progress = 1 - Clamp(floatingText.life / math.max(0.001, floatingText.maxLife), 0, 1)
        local x, y, scale = Renderer.WorldToScreen(width, height, floatingText.x, floatingText.y)
        x = x + (floatingText.offsetX or 0) * scale
        local alpha = math.floor(255 * (1 - progress) * (1 - progress))
        nvgFontSize(ctx, floatingText.size * scale * (1 + 0.18 * (1 - progress)))
        nvgFillColor(ctx, nvgRGBA(8, 8, 18, math.floor(alpha * 0.72)))
        nvgText(ctx, x + scale, y - floatingText.rise * progress * scale + scale, floatingText.text, nil)
        Color(ctx, floatingText.color, alpha)
        nvgText(ctx, x, y - floatingText.rise * progress * scale, floatingText.text, nil)
    end
end

local function DrawGuardStreak(ctx, width, height, feedback, game)
    local display = Feedback.GetGuardStreakDisplay(feedback)
    if display == nil then
        return
    end

    local remaining = Clamp(display.life / math.max(0.001, display.maxLife), 0, 1)
    local elapsed = 1 - remaining
    local popProgress = Clamp(elapsed / math.max(0.001, display.popDuration or 0.2), 0, 1)
    local popEase = 1 - (1 - popProgress) * (1 - popProgress)
    local fade = Clamp(remaining / 0.22, 0, 1)
    local alpha = math.floor(255 * fade)
    local profile = display.kind == "perfect" and FeedbackConfig.perfectStreak or FeedbackConfig.normalParry
    local text = "S"
    if display.kind == "perfect" then
        text = text .. string.rep("！", math.min(3, math.max(0, display.count - 1)))
    else
        text = "N"
    end

    local player = game ~= nil and game.player or nil
    local anchorX, anchorY
    if player ~= nil then
        anchorX, anchorY = Renderer.WorldToScreen(width, height, player.x, player.y)
        anchorY = anchorY - 62
    else
        anchorX, anchorY = Renderer.WorldToScreen(width, height, display.x, display.y)
    end

    local fontSize = profile.textSize * (0.68 + 0.32 * popEase)
    local iconSize = 46 * (0.78 + 0.22 * popEase)
    local hasPerfectIcon = display.kind == "perfect"
        and perfectStreakLightningImageHandle ~= nil and perfectStreakLightningImageHandle > 0
    local headOffsetX = hasPerfectIcon and 35 or 0
    local textX = anchorX + headOffsetX
    local sway = math.sin((feedback.time or 0) * 8.5) * (display.kind == "perfect" and 2.5 or 1.2)
    local lift = math.sin(popProgress * math.pi) * 5
    local textY = anchorY - lift

    if hasPerfectIcon then
        local iconX = anchorX - 28 + sway
        local iconY = textY - iconSize * 0.5
        nvgBeginPath(ctx)
        nvgRect(ctx, iconX - iconSize * 0.5, iconY - iconSize * 0.5, iconSize, iconSize)
        nvgFillPaint(ctx, nvgImagePatternTinted(ctx,
            iconX - iconSize * 0.5, iconY - iconSize * 0.5, iconSize, iconSize, 0,
            perfectStreakLightningImageHandle, nvgRGBA(255, 255, 255, alpha)))
        nvgFill(ctx)
    end

    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(ctx, fontSize)
    nvgFillColor(ctx, nvgRGBA(10, 11, 18, math.floor(alpha * 0.78)))
    nvgText(ctx, textX + sway + 2, textY + 3, text, nil)
    Color(ctx, profile.textColor, alpha)
    nvgText(ctx, textX + sway, textY, text, nil)

    local comboX, comboY = Renderer.WorldToScreen(width, height, display.comboX, display.comboY)
    local comboText = "x" .. tostring(display.comboCount) .. "连击"
    nvgFontSize(ctx, 17 * (0.75 + 0.25 * popEase))
    nvgFillColor(ctx, nvgRGBA(10, 11, 18, math.floor(alpha * 0.72)))
    nvgText(ctx, comboX + 1.5, comboY - 34 + 2, comboText, nil)
    nvgFillColor(ctx, nvgRGBA(235, 239, 247, alpha))
    nvgText(ctx, comboX, comboY - 34, comboText, nil)
end

local function DrawFeedbackFlash(ctx, width, height, feedback)
    if feedback == nil or feedback.flash == nil then
        return
    end

    local flash = feedback.flash
    local progress = Clamp(flash.timer / math.max(0.001, flash.maxTimer), 0, 1)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    Color(ctx, flash.color, math.floor(flash.alpha * progress * progress))
    nvgFill(ctx)
end

local function DrawChestPauseDim(ctx, width, height, game)
    if game.state ~= "chest_select" then
        return
    end
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(6, 6, 16, 100))
    nvgFill(ctx)
end

local function IsRoomMapped(game, roomId)
    if game.discoveredRooms[roomId] then
        return true
    end
    if game.room ~= nil then
        for _, targetRoomId in pairs(game.room.connections) do
            if targetRoomId == roomId then
                return true
            end
        end
    end
    return false
end

local function DrawMinimap(ctx, width, height, game)
    if game.room == nil or game.map == nil then
        return
    end

    local minX, maxX, minY, maxY = 0, 0, 0, 0
    for _, room in pairs(game.map.rooms) do
        minX, maxX = math.min(minX, room.mapX), math.max(maxX, room.mapX)
        minY, maxY = math.min(minY, room.mapY), math.max(maxY, room.mapY)
    end

    local cell = Clamp(math.min(width, height) * 0.021, 10, 15)
    local gap = 4
    local step = cell + gap
    local mapWidth = (maxX - minX) * step + cell
    local originX = width * 0.5 - mapWidth * 0.5
    local originY = math.max(10, height * 0.018)

    for _, room in pairs(game.map.rooms) do
        if IsRoomMapped(game, room.id) then
            local x = originX + (room.mapX - minX) * step
            local y = originY + (room.mapY - minY) * step
            for _, targetId in pairs(room.connections) do
                local target = game.map.rooms[targetId]
                if target ~= nil and IsRoomMapped(game, targetId) then
                    local targetX = originX + (target.mapX - minX) * step
                    local targetY = originY + (target.mapY - minY) * step
                    nvgBeginPath(ctx)
                    nvgMoveTo(ctx, x + cell * 0.5, y + cell * 0.5)
                    nvgLineTo(ctx, targetX + cell * 0.5, targetY + cell * 0.5)
                    nvgStrokeWidth(ctx, 2)
                    StrokeColor(ctx, { 150, 146, 160 }, 105)
                    nvgStroke(ctx)
                end
            end
        end
    end

    for roomId, room in pairs(game.map.rooms) do
        if IsRoomMapped(game, roomId) then
            local x = originX + (room.mapX - minX) * step
            local y = originY + (room.mapY - minY) * step
            local state = game.roomStates[roomId]
            local fill = { 68, 64, 76 }
            local alpha = 145
            if roomId == game.currentRoomId then
                fill, alpha = { 244, 210, 112 }, 255
            elseif state ~= nil and state.cleared then
                fill, alpha = { 112, 196, 151 }, 220
            elseif game.discoveredRooms[roomId] then
                fill, alpha = { 182, 108, 120 }, 220
            end

            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, x, y, cell, cell, 2)
            Color(ctx, fill, alpha)
            nvgFill(ctx)
            if room.boss then
                nvgStrokeWidth(ctx, 2)
                StrokeColor(ctx, { 235, 91, 92 }, 245)
                nvgStroke(ctx)
            end
        end
    end
end

local function GetTransitionOffset(game, width, height)
    local transition = game.transition
    if transition == nil or transition.duration <= 0 then
        return 0, 0
    end

    local progress = Clamp(transition.elapsed / transition.duration, 0, 1)
    local incomingX, incomingY = 0, 0
    if transition.direction == "north" then
        incomingY = -height
    elseif transition.direction == "south" then
        incomingY = height
    elseif transition.direction == "west" then
        incomingX = -width
    else
        incomingX = width
    end

    if not transition.switched then
        local outgoingProgress = math.min(1, progress * 2)
        return -incomingX * outgoingProgress, -incomingY * outgoingProgress
    end

    local incomingProgress = math.min(1, (progress - 0.5) * 2)
    return incomingX * (1 - incomingProgress), incomingY * (1 - incomingProgress)
end

function Renderer.Draw(ctx, game, width, height, feedback)
    DrawBackground(ctx, width, height, game.time)
    local offsetX, offsetY = GetTransitionOffset(game, width, height)
    local shakeX, shakeY = Feedback.GetScreenShake(feedback)
    nvgSave(ctx)
    nvgTranslate(ctx, shakeX, shakeY)
    nvgTranslate(ctx, offsetX, offsetY)
    DrawArena(ctx, width, height, game)
    DrawSpawnRoomGuide(ctx, width, height, game)
    DrawSpawnRoomParryGuide(ctx, width, height, game)
    if game.state == "intro" then
        DrawSpawnMarkers(ctx, width, height, game)
    end

    local boss = nil
    for _, enemy in ipairs(game.enemies) do
        if enemy.kind == "boss" then boss = enemy; break end
    end
    BossRenderer.DrawGround(ctx, width, height, boss, game.player, game.time, Renderer.WorldToScreen, false)

    local drawables = {}
    for _, chest in ipairs(game.chests) do table.insert(drawables, { kind = "chest", value = chest, y = chest.y }) end
    for _, projectile in ipairs(game.projectiles) do table.insert(drawables, { kind = "projectile", value = projectile, y = projectile.y }) end
    for _, enemy in ipairs(game.enemies) do table.insert(drawables, { kind = "enemy", value = enemy, y = enemy.y }) end
    if game.player ~= nil then table.insert(drawables, { kind = "player", value = game.player, y = game.player.y }) end
    table.sort(drawables, function(a, b) return a.y < b.y end)

    for _, drawable in ipairs(drawables) do
        if drawable.kind == "chest" then
            DrawChest(ctx, width, height, drawable.value)
        elseif drawable.kind == "projectile" then
            DrawProjectile(ctx, width, height, drawable.value, game.combo)
        elseif drawable.kind == "enemy" then
            if drawable.value.kind == "boss" then
                BossRenderer.DrawBoss(ctx, width, height, drawable.value, game.time, Renderer.WorldToScreen)
            else
                DrawEnemy(ctx, width, height, drawable.value, game.player, game.time)
            end
        else
            DrawPlayer(ctx, width, height, drawable.value, game.time)
        end
    end

    if game.player ~= nil then
        DrawParryCone(ctx, width, height, game.player)
    end
    DrawParticles(ctx, width, height, game.particles)
    BossRenderer.DrawMechanismTarget(ctx, width, height, boss, game.player, game.time, Renderer.WorldToScreen)
    DrawFeedbackWorld(ctx, width, height, feedback)
    nvgRestore(ctx)

    BossRenderer.DrawFog(ctx, width, height, boss, game.player, Renderer.WorldToScreen)

    DrawFeedbackFlash(ctx, width, height, feedback)
    DrawGuardStreak(ctx, width, height, feedback, game)
    DrawChestPauseDim(ctx, width, height, game)
    DrawMinimap(ctx, width, height, game)
end

return Renderer
