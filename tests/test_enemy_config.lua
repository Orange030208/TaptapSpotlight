package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local EnemyConfig = require "Data.EnemyConfig"
local RoomData = require "Data.RoomData"

local expectedKinds = {
    "soot", "blue_swarm", "tree", "sap", "ghost_a", "ghost_b", "stone",
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

assert(EnemyConfig.soot.attackRangeMeters == 5)
assert(EnemyConfig.tree.attackRangeMeters == 8)
assert(EnemyConfig.mushroom.attackRangeMeters == 15)
assert(EnemyConfig.dandelion.projectile.count == 5)
assert(EnemyConfig.sap.split.count == 2)
assert(EnemyConfig.dandelion.immovable)
assert(EnemyConfig.toxic_moss.immovable)
assert(not EnemyConfig.stone.immovable)

local encountered = {}
for _, room in pairs(RoomData.rooms) do
    if not room.boss then
        for _, group in ipairs(room.groups) do
            for _, kind in ipairs(group) do
                encountered[kind] = true
            end
        end
    end
end

for _, kind in ipairs(expectedKinds) do
    assert(encountered[kind], "enemy must appear in a normal room: " .. kind)
end

print("PASS test_enemy_config")
