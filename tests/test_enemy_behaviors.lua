package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local EnemyConfig = require "Data.EnemyConfig"
local Entities = require "Entities"
local Game = require "Game"

local function NewEnemy(kind, x, y, id)
    return Entities.NewEnemy(kind, { x = x, y = y }, id or 1)
end

local player = Entities.NewPlayer()
player.x, player.y = 0.5, 0.5

local farSoot = NewEnemy("soot", 0.08, 0.08, 1)
farSoot.stateTimer = 0
assert(Entities.IsEnemyInTrackingRange(farSoot, player),
    "ordinary enemies must track across the whole room by default")
assert(not Entities.IsEnemyInAttackRange(farSoot, player),
    "tracking range must not also start attacks")
local sootStartX, sootStartY = farSoot.x, farSoot.y
Entities.UpdateEnemy(farSoot, player, 0.1, function() end)
assert(farSoot.x > sootStartX and farSoot.y > sootStartY,
    "a tracking enemy must move toward a distant player")
assert(farSoot.state == "idle", "a distant target must not start a melee attack")

local attackSoot = NewEnemy("soot", 0.36, 0.5, 2)
attackSoot.stateTimer = 0
assert(Entities.IsEnemyInAttackRange(attackSoot, player))
Entities.UpdateEnemy(attackSoot, player, 0.01, function() end)
assert(attackSoot.state == "telegraph", "an enemy may attack after entering its attack range")

local rollingStone = NewEnemy("stone", 0.08, 0.08, 3)
rollingStone.stateTimer = 99
local stoneStartX, stoneStartY = rollingStone.x, rollingStone.y
Entities.UpdateEnemy(rollingStone, player, 0.1, function() end)
assert(rollingStone.x > stoneStartX and rollingStone.y > stoneStartY,
    "rolling enemies must also move while tracking")

local fixedDandelion = NewEnemy("dandelion", 0.3, 0.5, 4)
fixedDandelion.stateTimer = 99
local dandelionStartX, dandelionStartY = fixedDandelion.x, fixedDandelion.y
Entities.UpdateEnemy(fixedDandelion, player, 0.1, function() end)
assert(fixedDandelion.x == dandelionStartX and fixedDandelion.y == dandelionStartY,
    "immovable special enemies must remain fixed")

local sap = NewEnemy("sap", 0.4, 0.5, 3)
local splitChildren = Entities.GetSplitChildren(sap)
assert(#splitChildren == EnemyConfig.sap.split.count)
sap.splitGeneration = 1
assert(#Entities.GetSplitChildren(sap) == 0, "sap must split only once")

math.randomseed(137)
local dandelion = NewEnemy("dandelion", 0.3, 0.5, 4)
dandelion.stateTimer = 0
local dandelionWaves = {}
local elapsedDandelion = 0
for _ = 1, 420 do
    local wave = {}
    Entities.UpdateEnemy(dandelion, player, 0.01, function(projectile)
        table.insert(wave, projectile)
    end)
    if #wave > 0 then
        table.insert(dandelionWaves, { time = elapsedDandelion, seeds = wave })
    end
    elapsedDandelion = elapsedDandelion + 0.01
end
assert(#dandelionWaves >= 3, "dark dandelion must repeatedly release seed waves")
local smallestSeed = math.huge
local largestSeed = 0
local hasOffAxisSeed = false
for _, wave in ipairs(dandelionWaves) do
    assert(#wave.seeds == EnemyConfig.dandelion.projectile.count, "each wave must contain ten seeds")
    for _, projectile in ipairs(wave.seeds) do
        assert(projectile.style == "seed")
        assert(projectile.damage == 1)
        local speed = math.sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy)
        assert(math.abs(speed - EnemyConfig.dandelion.projectile.speed) < 0.000001)
        assert(projectile.radius >= EnemyConfig.dandelion.projectile.minRadius)
        assert(projectile.radius <= EnemyConfig.dandelion.projectile.maxRadius)
        smallestSeed = math.min(smallestSeed, projectile.radius)
        largestSeed = math.max(largestSeed, projectile.radius)
        hasOffAxisSeed = hasOffAxisSeed or math.abs(projectile.vy) > 0.001
    end
end
assert(largestSeed > smallestSeed, "dark dandelion seeds must vary in size")
assert(hasOffAxisSeed, "dark dandelion seeds must use 360 degree directions")
for index = 2, #dandelionWaves do
    local cadence = dandelionWaves[index].time - dandelionWaves[index - 1].time
    assert(math.abs(cadence - 1.2) <= 0.011, "dark dandelion waves must repeat every 1.2 seconds")
end

player.x, player.y = 0.5, 0.5
local mushroom = NewEnemy("mushroom", 0.3, 0.5, 13)
mushroom.stateTimer = 0
local mushroomShotTimes = {}
local elapsed = 0
for _ = 1, 180 do
    Entities.UpdateEnemy(mushroom, player, 0.01, function(projectile)
        table.insert(mushroomShotTimes, elapsed)
        assert(projectile.style == "spore")
        assert(projectile.damage == 1)
    end)
    elapsed = elapsed + 0.01
end
assert(#mushroomShotTimes >= 3, "mushroom must repeatedly fire spores")
for index = 2, #mushroomShotTimes do
    local cadence = mushroomShotTimes[index] - mushroomShotTimes[index - 1]
    assert(math.abs(cadence - 0.5) <= 0.011, "mushroom spore cadence must be 0.5 seconds")
end

local moss = NewEnemy("toxic_moss", player.x, player.y, 5)
assert(Entities.CollectEnemyHit(moss, player) ~= nil)
assert(Entities.CollectEnemyHit(moss, player) == nil, "moss must only hit on entry")
player.x = 0.9
assert(Entities.CollectEnemyHit(moss, player) == nil)
player.x = 0.5
assert(Entities.CollectEnemyHit(moss, player) ~= nil, "moss must reset after leaving")

local orb = NewEnemy("purple_orb", 0.5, 0.5, 6)
orb.state, orb.attackSerial = "active", 1
assert(Entities.CollectEnemyHit(orb, player) ~= nil)
assert(Entities.CollectEnemyHit(orb, player) == nil, "one AOE pulse may hit once")
orb.attackSerial = 2
assert(Entities.CollectEnemyHit(orb, player) ~= nil)

local pulsingOrb = NewEnemy("purple_orb", 0.5, 0.5, 14)
pulsingOrb.stateTimer = 0
local orbPulseTimes = {}
local elapsedOrb = 0
local lastAttackSerial = pulsingOrb.attackSerial
for _ = 1, 340 do
    Entities.UpdateEnemy(pulsingOrb, player, 0.01, function() end)
    if pulsingOrb.attackSerial ~= lastAttackSerial then
        table.insert(orbPulseTimes, elapsedOrb)
        lastAttackSerial = pulsingOrb.attackSerial
    end
    elapsedOrb = elapsedOrb + 0.01
end
assert(#orbPulseTimes >= 3, "purple orb must repeatedly emit AOE pulses")
for index = 2, #orbPulseTimes do
    local cadence = orbPulseTimes[index] - orbPulseTimes[index - 1]
    assert(math.abs(cadence - 1) <= 0.011, "purple orb AOE cadence must be one second")
end

local tree = NewEnemy("tree", 0.5, 0.5, 7)
tree.state, tree.attackSerial, tree.attackX, tree.attackY, tree.attackArc = "active", 1, 1, 0, 180
player.x, player.y = 0.62, 0.5
assert(Entities.CollectEnemyHit(tree, player) ~= nil)
tree.attackSerial = 2
player.x = 0.35
assert(Entities.CollectEnemyHit(tree, player) == nil, "tree's rear must be safe")

local stone = NewEnemy("stone", 0.5, 0.5, 8)
stone.state, stone.attackSerial = "dash", 1
player.x, player.y = 0.5, 0.5
assert(Entities.CollectEnemyHit(stone, player) ~= nil)
assert(Entities.CollectEnemyHit(stone, player) == nil, "rolling impact may hit once")

local parryGhost = NewEnemy("ghost_a", 0.6, 0.5, 9)
player.parryTimer, player.parryDirectionX, player.parryDirectionY = 1, 1, 0
assert(Entities.TryParryEnemy(player, parryGhost, 1))
assert(parryGhost.state == "stagger")

local luminousWraith = NewEnemy("luminous_wraith", 0.7, 0.5, 10)
luminousWraith.stateTimer = 0
local wraithStartX = luminousWraith.x
Entities.UpdateEnemy(luminousWraith, player, 0.1, function() end)
assert(luminousWraith.x < wraithStartX, "luminous wraith must immediately pursue the player")
luminousWraith.x, luminousWraith.y = player.x, player.y
assert(Entities.CollectEnemyHit(luminousWraith, player) ~= nil, "luminous wraith must deal contact damage")
assert(Entities.CollectEnemyHit(luminousWraith, player) == nil, "luminous wraith contact damage must respect cooldown")
player.parryTimer, player.parryDirectionX, player.parryDirectionY = 1, 1, 0
assert(Entities.TryParryEnemy(player, luminousWraith, 1))
assert(luminousWraith.state == "stagger")

local fixedMoss = NewEnemy("toxic_moss", 0.5, 0.5, 11)
local movingSoot = NewEnemy("soot", 0.5, 0.5, 12)
Entities.ResolveEnemySeparation({ fixedMoss, movingSoot })
assert(fixedMoss.x == 0.5 and fixedMoss.y == 0.5, "ground hazards must remain fixed")

local splitGame = Game.New()
Game.StartOrRestart(splitGame)
Game.ConsumeEvents(splitGame)
splitGame.state = "battle"
local splitSap = NewEnemy("sap", splitGame.player.x + 0.12, splitGame.player.y, 12)
splitSap.hp, splitSap.maxHp, splitSap.state, splitSap.stateTimer = 0.5, 0.5, "dash", 1
splitGame.enemies = { splitSap }
assert(Game.TryParry(splitGame))
Game.Update(splitGame, 0, 0, 0)
assert(#splitGame.enemies == EnemyConfig.sap.split.count, "defeated sap must create two children")
for _, child in ipairs(splitGame.enemies) do
    assert(child.kind == "sap" and child.splitGeneration == 1)
end

print("PASS test_enemy_behaviors")
