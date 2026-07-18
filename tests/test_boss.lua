package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local BossConfig = require "Data.BossConfig"
local EnemyConfig = require "Data.EnemyConfig"
local PlayerConfig = require "Data.PlayerConfig"
local Boss = require "Boss"

local function NewPlayer(x, y, facing)
    return {
        x = x, y = y, radius = PlayerConfig.radius, facing = facing or "right",
        parryHalfAngleCos = PlayerConfig.parryHalfAngleCos,
    }
end

local function NewBoss()
    return Boss.Initialize({
        id = 1, kind = "boss", x = 0.5, y = 0.5, radius = EnemyConfig.boss.radius,
        hp = EnemyConfig.boss.hp, maxHp = EnemyConfig.boss.hp, facing = "right",
        state = "idle", stateTimer = 1, dead = false, vx = 0, vy = 0,
    })
end

local function SetActive(boss, attack, pulse)
    boss.state = "active"
    boss.attack = attack
    boss.stateTimer = 1
    boss.attackTimer = 0
    boss.attackHitToken = nil
    boss.featherPulse = pulse or 0
    boss.parriedPulse = 0
end

-- Five attack shapes and their safe sides/ranges.
local boss = NewBoss()
SetActive(boss, "sweep")
assert(Boss.IsAttackHitting(boss, NewPlayer(0.63, 0.5)))
assert(not Boss.IsAttackHitting(boss, NewPlayer(0.37, 0.5)), "sweep must leave the rear safe")

SetActive(boss, "skewer")
assert(Boss.IsAttackHitting(boss, NewPlayer(0.78, 0.53)))
assert(Boss.IsAttackHitting(boss, NewPlayer(0.22, 0.47)))
assert(not Boss.IsAttackHitting(boss, NewPlayer(0.5, 0.64)), "skewer must stay in its narrow lane")

SetActive(boss, "charge")
assert(Boss.IsAttackHitting(boss, NewPlayer(0.58, 0.5)))
assert(not Boss.IsAttackHitting(boss, NewPlayer(0.8, 0.5)))

SetActive(boss, "quake")
assert(Boss.IsAttackHitting(boss, NewPlayer(0.5, 0.32)), "270-degree quake includes the side")
assert(not Boss.IsAttackHitting(boss, NewPlayer(0.36, 0.5)), "quake rear wedge must be safe")

SetActive(boss, "feathers", 1)
assert(Boss.IsAttackHitting(boss, NewPlayer(0.35, 0.5)), "first four feather pulses target the rear")
assert(not Boss.IsAttackHitting(boss, NewPlayer(0.65, 0.5)))
boss.featherPulse = 5
assert(Boss.IsAttackHitting(boss, NewPlayer(0.65, 0.5)), "last four feather pulses target the front")

-- A non-feather attack only reports one hit; each feather pulse may report once.
SetActive(boss, "sweep")
local player = NewPlayer(0.63, 0.5)
assert(#Boss.CollectPlayerHits(boss, player) == 1)
assert(#Boss.CollectPlayerHits(boss, player) == 0)
SetActive(boss, "feathers", 5)
assert(#Boss.CollectPlayerHits(boss, player) == 1)
assert(#Boss.CollectPlayerHits(boss, player) == 0)
boss.featherPulse = 6
assert(#Boss.CollectPlayerHits(boss, player) == 1)

-- Distance increases the charge selection band without allowing repeats.
boss = NewBoss()
local nearPlayer = NewPlayer(0.7, 0.5)
local farPlayer = NewPlayer(0.9, 0.5)
local nearChoice = Boss.SelectAttack(boss, nearPlayer, 0.40)
local farChoice = Boss.SelectAttack(boss, farPlayer, 0.40)
assert(nearChoice == "skewer", "near choice was " .. tostring(nearChoice))
assert(farChoice == "charge", "far choice was " .. tostring(farChoice))
boss.lastAttack = "charge"
assert(Boss.SelectAttack(boss, farPlayer, 0.40) ~= "charge")

-- Phase one locks at 30%, then boss attacks become defensive-only.
boss = NewBoss()
player = NewPlayer(0.62, 0.5, "left")
boss.hp = boss.maxHp * BossConfig.phaseThreshold + 0.2
SetActive(boss, "sweep")
local result = assert(Boss.TryParry(boss, player, 1))
assert(result.kind == "attack" and math.abs(result.damage - 0.2) < 0.0001)
assert(math.abs(boss.hp - boss.maxHp * BossConfig.phaseThreshold) < 0.0001)
assert(boss.phase == 2 and boss.state == "phase_transition")
Boss.Update(boss, player, BossConfig.phaseTransitionDuration + 0.01)
SetActive(boss, "sweep")
local phaseTwoHp = boss.hp
result = assert(Boss.TryParry(boss, player, 99))
assert(result.damage == 0 and not result.grantsGauge and boss.hp == phaseTwoHp)

-- Attack interception has priority over the current mechanism.
boss = NewBoss()
boss.phase = 2
boss.mechanism = "fog"
boss.mechanismProgress = 0
boss.fogSide = 1
boss.mechanismTransition = 0
player = NewPlayer(0.61, 0.5, "left")
SetActive(boss, "sweep")
result = assert(Boss.TryParry(boss, player, 1))
assert(result.kind == "attack" and boss.mechanismProgress == 0)

boss.state, boss.stateTimer = "idle", 1
boss.attack = nil
boss.lastParrySerial = -1
player.parrySerial = 10
local fogX = Boss.GetMechanismTarget(boss, player)
player.facing = fogX < player.x and "left" or "right"
assert(Boss.TryParry(boss, player, 1) ~= nil)
assert(Boss.TryParry(boss, player, 1) == nil, "one parry press must advance at most one target")

-- Sequential 3/4/5 mechanism progression.
boss.state = "idle"
boss.stateTimer = 1
boss.mechanism = "fog"
boss.fogSide = -1
boss.mechanismProgress = 0
boss.lastParrySerial = -1
player = NewPlayer(0.5, 0.5, "left")
for index = 1, BossConfig.mechanisms.fog.required do
    local x = Boss.GetMechanismTarget(boss, player)
    player.facing = x < player.x and "left" or "right"
    result = assert(Boss.TryParry(boss, player, 1))
    assert(result.kind == "mechanism")
end
assert(boss.mechanism == "thorns" and boss.thorn ~= nil)

boss.mechanismTransition = 0
boss.state = "idle"
boss.stateTimer = 1
for _ = 1, BossConfig.mechanisms.thorns.required do
    local thorn = boss.thorn
    thorn.state, thorn.direction, thorn.cycle = "active", 1, thorn.cycle + 1
    player.x = thorn.x + 0.08
    player.y = thorn.y
    player.facing = "left"
    result = assert(Boss.TryParry(boss, player, 1))
end
assert(boss.mechanism == "metal" and boss.thorn == nil)

boss.mechanismTransition = 0
boss.state = "idle"
boss.stateTimer = 1
boss.facing = "right"
local metalX, metalY = Boss.GetMechanismTarget(boss, player)
player.x, player.y, player.facing = metalX - 0.03, metalY, "right"
for _ = 1, BossConfig.mechanisms.metal.required do
    result = assert(Boss.TryParry(boss, player, 1))
    if boss.state ~= "purifying" then boss.state, boss.stateTimer = "idle", 1 end
end
assert(boss.state == "purifying" and not boss.dead)
Boss.Update(boss, player, BossConfig.purificationDuration * 0.5)
assert(boss.purificationProgress > 0 and not boss.dead)
Boss.Update(boss, player, BossConfig.purificationDuration * 0.5 + 0.01)
assert(boss.dead and boss.purified)

-- Metal cannot be pulled from the front or during an attack.
boss = NewBoss()
boss.phase, boss.mechanism, boss.mechanismTransition = 2, "metal", 0
boss.state, boss.facing = "idle", "right"
metalX, metalY = Boss.GetMechanismTarget(boss, player)
player.x, player.y, player.facing = boss.x + 0.03, metalY, "left"
assert(Boss.TryParry(boss, player, 1) == nil)
player.x, player.facing = metalX - 0.02, "right"
boss.state, boss.attack = "active", "sweep"
assert(Boss.TryParry(boss, player, 1) == nil)

print("PASS test_boss")
