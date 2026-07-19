package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local EnemyConfig = require "Data.EnemyConfig"
local RoomData = require "Data.RoomData"

local expectedKinds = {
    "soot", "blue_swarm", "tree", "sap", "shadow_wraith", "stone",
    "mushroom", "dandelion", "purple_orb", "toxic_moss",
}

assert(EnemyConfig.roomWidthMeters == 30)
assert(math.abs(EnemyConfig.MetersToWorld(5) - 1 / 6) < 0.000001)
assert(math.abs(EnemyConfig.MetersToWorld(15) - 0.5) < 0.000001)
assert(EnemyConfig.defaultTrackingRangeMeters > EnemyConfig.roomWidthMeters,
    "the default tracking range must cover the room diagonal")
assert(math.abs(EnemyConfig.defaultTrackingRange - math.sqrt(2)) < 0.000001,
    "the default tracking range must cover every point in normalized room space")

for _, kind in ipairs(expectedKinds) do
    local spec = assert(EnemyConfig[kind], "missing enemy config: " .. kind)
    assert(type(spec.behavior) == "string" and spec.behavior ~= "")
    assert(type(spec.hp) == "number" and spec.hp > 0)
    assert(type(spec.radius) == "number" and spec.radius > 0)
    assert(type(spec.visual) == "table" and type(spec.visual.primary) == "table")
    assert(spec.activationRange == nil and spec.activationRangeMeters == nil,
        "activation range must be replaced by separate tracking and attack ranges")
    if spec.attack ~= nil then
        assert(type(spec.attackRangeMeters) == "number" and spec.attackRangeMeters > 0)
        assert(type(spec.attackRange) == "number" and spec.attackRange > 0)
    end
end

assert(EnemyConfig.soot.attackRangeMeters == 8)
assert(EnemyConfig.blue_swarm.behavior == "aoe_pulse")
assert(EnemyConfig.blue_swarm.attackRangeMeters == 3.5)
assert(EnemyConfig.blue_swarm.attack.repeatInterval == 0.7)
assert(EnemyConfig.blue_swarm.attack.telegraph == 0.17)
assert(EnemyConfig.blue_swarm.moveSpeed >= 0.3, "blue swarm must move quickly")
assert(EnemyConfig.tree.attackRangeMeters == 4)
assert(EnemyConfig.tree.attack.range == EnemyConfig.MetersToWorld(4))
assert(EnemyConfig.tree.attack.arc == 60)
assert(EnemyConfig.tree.attack.repeatInterval == 1.5)
assert(EnemyConfig.tree.moveSpeed <= 0.12, "tree monster movement must stay slow")
assert(EnemyConfig.tree.touchDamage == 2, "tree monster must deal high melee damage")
assert(EnemyConfig.mushroom.attackRangeMeters == 12)
assert(EnemyConfig.mushroom.moveSpeed <= 0.1, "mushroom movement must stay low")
assert(EnemyConfig.mushroom.attack.repeatInterval == 0.5, "mushroom must fire every 0.5 seconds")
assert(EnemyConfig.mushroom.projectile.count == 1, "mushroom must fire one spore")
assert(EnemyConfig.mushroom.projectile.style == "spore")
assert(EnemyConfig.mushroom.projectile.damage == 1, "mushroom spore damage must stay low")
assert(EnemyConfig.dandelion.moveSpeed == 0, "dark dandelion must not move")
assert(EnemyConfig.dandelion.attack.repeatInterval == 1.2, "dark dandelion must fire every 1.2 seconds")
assert(EnemyConfig.dandelion.projectile.count == 10, "dark dandelion must fire ten seeds")
assert(EnemyConfig.dandelion.projectile.pattern == "radial_random")
assert(EnemyConfig.dandelion.projectile.minRadius < EnemyConfig.dandelion.projectile.maxRadius)
assert(EnemyConfig.dandelion.projectile.style == "seed")
assert(EnemyConfig.dandelion.projectile.damage == 1, "dark dandelion seed damage must stay low")
assert(EnemyConfig.purple_orb.behavior == "ranged_single")
assert(EnemyConfig.purple_orb.hp == 1, "purple orb must be defeated by one successful reflection")
assert(EnemyConfig.purple_orb.attackRangeMeters == 8)
assert(EnemyConfig.purple_orb.attack.repeatInterval == 1.75, "purple orb must leave time between shots")
assert(EnemyConfig.purple_orb.attack.telegraph == 0.65, "purple orb must clearly telegraph each shot")
assert(EnemyConfig.purple_orb.moveSpeed == 0.08, "purple orb must move slowly")
assert(EnemyConfig.purple_orb.projectile.count == 1, "purple orb must fire one bolt")
assert(EnemyConfig.purple_orb.projectile.speed == 0.28, "purple orb bolt must be slow")
assert(EnemyConfig.purple_orb.projectile.radius == 0.013, "purple orb bolt must be narrow")
assert(EnemyConfig.purple_orb.touchDamage == 1, "purple orb damage must stay low")
assert(EnemyConfig.sap.behavior == "melee_arc")
assert(EnemyConfig.sap.attackRangeMeters == 1.5)
assert(EnemyConfig.sap.attack.range == EnemyConfig.MetersToWorld(1.5))
assert(EnemyConfig.sap.attack.arc == 60)
assert(EnemyConfig.sap.split.count == 2)
assert(EnemyConfig.sap.split.childHpRatio == 0.5)
assert(EnemyConfig.dandelion.immovable)
assert(EnemyConfig.toxic_moss.immovable)
assert(not EnemyConfig.stone.immovable)
assert(EnemyConfig.stone.behavior == "rolling")
assert(EnemyConfig.stone.moveSpeed >= 0.25, "stone must quickly pursue the player")
assert(EnemyConfig.stone.attack.telegraph == 0.27, "stone charge must visibly telegraph before charging")
assert(EnemyConfig.stone.attack.dashSpeed >= 1.4, "stone charge must be fast")
assert(EnemyConfig.shadow_wraith.behavior == "contact_chase")
assert(EnemyConfig.shadow_wraith.moveSpeed == 0.2)
assert(EnemyConfig.shadow_wraith.touchDamage == 1)
assert(EnemyConfig.shadow_wraith.contactCooldown == 2.45)

local purpleOrbCount = 0
for _, spawn in ipairs(RoomData.rooms.room_8.fixedSpawns) do
    if spawn.kind == "purple_orb" then
        purpleOrbCount = purpleOrbCount + 1
    end
end
assert(purpleOrbCount == 3, "the toxic moss room must contain only three purple orbs")

local encountered = {}
for _, room in pairs(RoomData.rooms) do
    if not room.boss then
        for _, group in ipairs(room.groups or {}) do
            for _, kind in ipairs(group) do
                encountered[kind] = true
            end
        end
        for _, spawn in ipairs(room.fixedSpawns or {}) do
            encountered[spawn.kind] = true
        end
    end
end

local expectedEncounteredKinds = {
    "soot", "tree", "sap", "shadow_wraith", "stone", "mushroom",
    "dandelion", "purple_orb", "toxic_moss",
}

for _, kind in ipairs(expectedEncounteredKinds) do
    assert(encountered[kind], "enemy must appear in a normal room: " .. kind)
end

print("PASS test_enemy_config")
