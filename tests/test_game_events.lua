package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local GaugeConfig = require "Data.GaugeConfig"
local ComboConfig = require "Data.ComboConfig"
local BossConfig = require "Data.BossConfig"
local ChestConfig = require "Data.ChestConfig"
local PlayerConfig = require "Data.PlayerConfig"
local ProjectileConfig = require "Data.ProjectileConfig"
local RoomConfig = require "Data.RoomConfig"
local CrystalConfig = require "Data.CrystalConfig"
local Entities = require "Entities"
local Game = require "Game"

for _, definition in ipairs(CrystalConfig.definitions) do
    assert(type(definition.iconKind) == "string" and definition.iconKind ~= "", "every crystal needs an icon kind")
end

local function HasEvent(events, name)
    for _, event in ipairs(events) do
        if event.name == name then
            return true
        end
    end
    return false
end

local function FindEvent(events, name)
    for _, event in ipairs(events) do
        if event.name == name then
            return event
        end
    end
    return nil
end

local game = Game.New()
local menuHud = Game.GetHud(game)
assert(menuHud.hudVisible == false, "the combat HUD must stay hidden on the main menu")
assert(#Game.ConsumeEvents(game) == 0)

game.stateBeforeChest = "stale"
Game.StartOrRestart(game)
assert(game.stateBeforeChest == nil, "starting a run must clear transient chest state")
local runHud = Game.GetHud(game)
assert(runHud.hudVisible == true, "the combat HUD must be visible during a run")
assert(runHud.healthRatio == 1, "a fresh run must expose a full health ratio")
assert(runHud.gaugeRatio == 0, "a fresh run must expose an empty gauge ratio")
local events = Game.ConsumeEvents(game)
assert(HasEvent(events, "run_start"))
assert(#Game.ConsumeEvents(game) == 0, "consuming events must clear the queue")

game.state = "battle"
assert(Game.TryParry(game))
events = Game.ConsumeEvents(game)
assert(HasEvent(events, "parry_start"))
local parryStart = FindEvent(events, "parry_start")
assert(type(parryStart.data) == "table" and type(parryStart.data.x) == "number")

local directional = Game.New()
Game.StartOrRestart(directional)
Game.ConsumeEvents(directional)
directional.state = "battle"
local upperEnemy = Entities.NewEnemy("soot", {
    x = directional.player.x,
    y = directional.player.y - 0.12,
}, 101)
local lowerEnemy = Entities.NewEnemy("soot", {
    x = directional.player.x,
    y = directional.player.y + 0.12,
}, 102)
upperEnemy.state, upperEnemy.stateTimer = "dash", 0.5
lowerEnemy.state, lowerEnemy.stateTimer = "dash", 0.5
directional.enemies = { upperEnemy, lowerEnemy }
assert(Game.TryParry(directional, directional.player.x, directional.player.y - 1))
Game.ConsumeEvents(directional)
Game.Update(directional, 0, 0, 0)
assert(upperEnemy.state == "recovery", "an upward guard must parry the upper threat")
assert(lowerEnemy.state == "dash", "an upward guard must not parry the lower threat")
assert(directional.player.parryCooldown <= PlayerConfig.successfulParryCooldown,
    "a successful parry must compress its remaining cooldown")

local movementLock = Game.New()
Game.StartOrRestart(movementLock)
Game.ConsumeEvents(movementLock)
movementLock.state = "battle"
movementLock.enemies = { Entities.NewEnemy("soot", { x = 0.1, y = 0.1 }, 103) }
movementLock.enemies[1].stateTimer = 99
local lockedX, lockedY = movementLock.player.x, movementLock.player.y
assert(Game.TryParry(movementLock, movementLock.player.x + 1, movementLock.player.y))
Game.Update(movementLock, 0.05, 1, -1)
assert(movementLock.player.x == lockedX and movementLock.player.y == lockedY,
    "the player must not move while the parry window is active")

local buffered = Game.New()
Game.StartOrRestart(buffered)
Game.ConsumeEvents(buffered)
buffered.state = "battle"
buffered.enemies = { Entities.NewEnemy("soot", { x = 0.1, y = 0.1 }, 104) }
buffered.enemies[1].stateTimer = 99
buffered.player.parryCooldown = PlayerConfig.parryInputBuffer - 0.01
assert(Game.TryParry(buffered, buffered.player.x, buffered.player.y - 1),
    "an input inside the cooldown-end buffer must be accepted")
assert(not Entities.IsParrying(buffered.player), "buffered input must wait for cooldown completion")
assert(not HasEvent(Game.ConsumeEvents(buffered), "parry_start"),
    "buffered input must not announce a parry before it starts")
Game.Update(buffered, PlayerConfig.parryInputBuffer, 0, 0)
assert(Entities.IsParrying(buffered.player), "buffered parry must start when cooldown reaches zero")
assert(buffered.player.parryDirectionY < -0.99, "buffered parry must preserve the clicked direction")
assert(HasEvent(Game.ConsumeEvents(buffered), "parry_start"),
    "starting a buffered parry must emit its start event")

local tooEarly = Game.New()
Game.StartOrRestart(tooEarly)
Game.ConsumeEvents(tooEarly)
tooEarly.state = "battle"
tooEarly.player.parryCooldown = PlayerConfig.parryInputBuffer + 0.01
assert(not Game.TryParry(tooEarly, tooEarly.player.x, tooEarly.player.y - 1),
    "inputs before the cooldown-end buffer must still be rejected")

game.state = "chest_select"
game.stateBeforeChest = "battle"
game.chestOptions = { CrystalConfig.definitions[1] }
assert(Game.SelectCrystal(game, 1))
assert(game.state == "battle" and game.stateBeforeChest == nil)
events = Game.ConsumeEvents(game)
assert(HasEvent(events, "crystal_acquired"))

local battle = Game.New()
Game.StartOrRestart(battle)
Game.ConsumeEvents(battle)
assert(battle.currentRoomId == "threshold")
assert(battle.state == "clear" and not battle.roomCleared, "the birth room must lock exits until its tutorial is complete")
assert(#battle.enemies == 0 and battle.clearedRoomCount == 0, "the birth room must not spawn or count combat")
assert(battle.spawnGuideAlpha == 1, "the birth room must expose its WASD floor guide")
local birthX = battle.player.x
Game.Update(battle, 0.1, 1, 0)
assert(battle.player.x > birthX and battle.spawnGuideAlpha < 1, "movement must dismiss the floor guide")
assert(battle.spawnParryGuideAlpha == 1, "movement must reveal the mouse parry guide")
assert(Game.TryParry(battle, battle.player.x + 1, battle.player.y, true), "the left-click tutorial must allow a parry")
assert(battle.spawnParryGuideAlpha == 0, "the mouse parry guide must disappear immediately after a successful click")
assert(battle.roomCleared, "movement and parry must unlock the birth room exits")
battle.player.x, battle.player.y = 0.5, RoomConfig.minY
Game.Update(battle, 0, 0, 0)
assert(HasEvent(Game.ConsumeEvents(battle), "room_transition"), "the birth room north door must be usable")
battle.transition = nil
battle.doorCooldown = 0

local reflectTutorial = Game.New()
Game.StartOrRestart(reflectTutorial)
Game.ConsumeEvents(reflectTutorial)
Game.Update(reflectTutorial, 0.1, 1, 0)
assert(Game.TryParry(reflectTutorial, reflectTutorial.player.x + 1, reflectTutorial.player.y, true))
reflectTutorial.player.x, reflectTutorial.player.y = 0.5, RoomConfig.minY
Game.Update(reflectTutorial, 0, 0, 0)
assert(reflectTutorial.state == "room_transition")
Game.Update(reflectTutorial, RoomConfig.transitionDuration * 0.5, 0, 0)

local reflectRoom = reflectTutorial.room
local tutorialSpawn = reflectRoom.tutorialSpawn
assert(reflectRoom.id == "crossfire" and reflectRoom.isReflectTutorial)
assert(#reflectRoom.spawns == 0 and tutorialSpawn.randomized, "the reflection tutorial must not use fixed spawn points")
assert(#reflectTutorial.enemies == tutorialSpawn.count and tutorialSpawn.count == 2)
for index, enemy in ipairs(reflectTutorial.enemies) do
    assert(enemy.kind == tutorialSpawn.kind and tutorialSpawn.kind == "soot")
    assert(enemy.x >= tutorialSpawn.area.minX and enemy.x <= tutorialSpawn.area.maxX)
    assert(enemy.y >= tutorialSpawn.area.minY and enemy.y <= tutorialSpawn.area.maxY)
    local playerDistance = math.sqrt((enemy.x - reflectTutorial.player.x) ^ 2 + (enemy.y - reflectTutorial.player.y) ^ 2)
    assert(playerDistance >= tutorialSpawn.minPlayerDistance)
    for previous = 1, index - 1 do
        local other = reflectTutorial.enemies[previous]
        local separation = math.sqrt((enemy.x - other.x) ^ 2 + (enemy.y - other.y) ^ 2)
        assert(separation >= tutorialSpawn.minSeparation)
    end
end

battle.state = "battle"
battle.enemies = { Entities.NewEnemy("mushroom", { x = 0.2, y = 0.2 }, 1001) }
battle.enemies[1].state = "telegraph"
battle.enemies[1].stateTimer = 0
battle.player.x, battle.player.y = 0.8, 0.8
Game.Update(battle, 0.01, 0, 0)
assert(HasEvent(Game.ConsumeEvents(battle), "projectile_fire"))

local hurt = Game.New()
Game.StartOrRestart(hurt)
Game.ConsumeEvents(hurt)
hurt.state = "battle"
hurt.player.hp = 1
hurt.enemies = {}
hurt.projectiles = { Entities.NewProjectile(hurt.player.x, hurt.player.y, 0, 0, "enemy", 1) }
Game.Update(hurt, 0, 0, 0)
events = Game.ConsumeEvents(hurt)
assert(HasEvent(events, "player_hurt"))
assert(HasEvent(events, "game_over"))
assert(FindEvent(events, "player_hurt").data.amount == 1)

local parry = Game.New()
Game.StartOrRestart(parry)
Game.ConsumeEvents(parry)
parry.state = "battle"
parry.enemies = { Entities.NewEnemy("soot", { x = parry.player.x + 0.12, y = parry.player.y }, 2001) }
parry.enemies[1].hp = 0.5
parry.enemies[1].state = "dash"
parry.enemies[1].stateTimer = 0.5
assert(Game.TryParry(parry))
Game.ConsumeEvents(parry)
Game.Update(parry, 0, 0, 0)
events = Game.ConsumeEvents(parry)
assert(HasEvent(events, "perfect_parry"))
assert(HasEvent(events, "damage_dealt"), "perfect melee parries must emit a damage popup event")
assert(HasEvent(events, "enemy_defeat"))
assert(HasEvent(events, "room_clear"))
assert(FindEvent(events, "perfect_parry").data.damage > 0)
assert(FindEvent(events, "perfect_parry").data.originX == parry.player.x)
assert(FindEvent(events, "perfect_parry").data.directionX > 0)
assert(FindEvent(events, "enemy_defeat").data.kind == "soot")
assert(parry.gauge.value == GaugeConfig.perfectGain, "killing an enemy must preserve gauge progress")

local wraithContact = Game.New()
Game.StartOrRestart(wraithContact)
Game.ConsumeEvents(wraithContact)
wraithContact.state = "battle"
wraithContact.enemies = {
    Entities.NewEnemy("shadow_wraith", { x = wraithContact.player.x + 0.05, y = wraithContact.player.y }, 2002),
}
Game.Update(wraithContact, 0, 0, 0)
events = Game.ConsumeEvents(wraithContact)
local wraithEffect = FindEvent(events, "shadow_wraith_hit")
assert(wraithEffect ~= nil, "shadow wraith contact must emit an effect event")
assert(wraithEffect.data.originX > wraithEffect.data.x and wraithEffect.data.directionX < 0,
    "shadow wraith effect must point from the attacker toward the player")

local reflect = Game.New()
Game.StartOrRestart(reflect)
Game.ConsumeEvents(reflect)
reflect.state = "battle"
reflect.enemies = { Entities.NewEnemy("soot", { x = 0.2, y = 0.2 }, 3001) }
reflect.enemies[1].stateTimer = 99
reflect.player.facing = "right"
reflect.projectiles = { Entities.NewProjectile(reflect.player.x + 0.04, reflect.player.y, -0.1, 0, "enemy", 1, "mushroom") }
assert(Game.TryParry(reflect, reflect.player.x + 1, reflect.player.y))
reflect.player.parryElapsed = PlayerConfig.perfectParryWindow + 0.01
Game.ConsumeEvents(reflect)
Game.Update(reflect, 0, 0, 0)
events = Game.ConsumeEvents(reflect)
assert(HasEvent(events, "parry_success"))
assert(HasEvent(events, "projectile_reflect"))
assert(FindEvent(events, "projectile_reflect").data.sourceKind == "mushroom")
assert(reflect.projectiles[1].vx > 0 and math.abs(reflect.projectiles[1].vy) < 0.0001,
    "a reflected projectile must travel along the clicked guard direction")

local perfectReflect = Game.New()
Game.StartOrRestart(perfectReflect)
Game.ConsumeEvents(perfectReflect)
perfectReflect.state = "battle"
perfectReflect.projectiles = {
    Entities.NewProjectile(perfectReflect.player.x + 0.04, perfectReflect.player.y, -0.1, 0, "enemy", 1, "mushroom"),
}
assert(Game.TryParry(perfectReflect, perfectReflect.player.x + 1, perfectReflect.player.y))
Game.Update(perfectReflect, 0, 0, 0)
assert(perfectReflect.projectiles[1].damage == ProjectileConfig.perfectReflectedDamage,
    "a perfect reflection must use the configured base damage")

local reflectedShot = Game.New()
Game.StartOrRestart(reflectedShot)
Game.ConsumeEvents(reflectedShot)
reflectedShot.state = "battle"
for _, definition in ipairs(CrystalConfig.definitions) do
    reflectedShot.player.crystals[definition.id] = definition.maxStacks
end
local firstTarget = Entities.NewEnemy("soot", { x = 0.35, y = 0.5 }, 3101)
local secondTarget = Entities.NewEnemy("soot", { x = 0.55, y = 0.7 }, 3102)
for _, enemy in ipairs({ firstTarget, secondTarget }) do
    enemy.hp = 1
    enemy.stateTimer = 99
end
reflectedShot.enemies = { firstTarget, secondTarget }
local reflectedProjectile = Entities.NewProjectile(firstTarget.x, firstTarget.y, 0.2, 0, "player", 2, "mushroom")
reflectedProjectile.reflected = true
reflectedProjectile.pierceRemaining = 1
reflectedShot.projectiles = { reflectedProjectile }
Game.Update(reflectedShot, 0, 0, 0)
assert(reflectedProjectile.vx == 0.2 and reflectedProjectile.vy == 0,
    "a reflected projectile must keep its original direction after a kill")
assert(reflectedProjectile.pierceRemaining == 0 and reflectedProjectile.hitEnemies[firstTarget.id],
    "a reflected projectile must consume penetration without tracking another target")

reflectedProjectile.x, reflectedProjectile.y = secondTarget.x, secondTarget.y
Game.Update(reflectedShot, 0, 0, 0)
assert(reflectedProjectile.dead and #reflectedShot.projectiles == 0,
    "a reflected projectile must expire after its penetration is exhausted")

local comboGame = Game.New()
Game.StartOrRestart(comboGame)
Game.ConsumeEvents(comboGame)
comboGame.state = "battle"

local function PerformPerfectComboParry(id)
    comboGame.player.parryTimer = 0
    comboGame.player.parryCooldown = 0
    local enemy = Entities.NewEnemy("soot", { x = comboGame.player.x + 0.12, y = comboGame.player.y }, id)
    enemy.hp = 10
    enemy.state, enemy.stateTimer = "dash", 0.5
    comboGame.enemies = { enemy }
    assert(Game.TryParry(comboGame, comboGame.player.x + 1, comboGame.player.y))
    Game.Update(comboGame, 0, 0, 0)
    return Game.ConsumeEvents(comboGame)
end

local comboEvents = PerformPerfectComboParry(3201)
assert(comboGame.combo.count == ComboConfig.perfectGain and comboGame.combo.tier == 0)
assert(FindEvent(comboEvents, "perfect_parry").data.perfectStreak == 1,
    "the first perfect parry must begin a separate visual streak")
comboEvents = PerformPerfectComboParry(3202)
assert(comboGame.combo.count == ComboConfig.perfectGain * 2 and comboGame.combo.tier == 1)
assert(HasEvent(comboEvents, "combo_tier_up"))
assert(FindEvent(comboEvents, "perfect_parry").data.perfectStreak == 2,
    "each consecutive perfect parry must increment the visual streak by one")
comboEvents = PerformPerfectComboParry(3203)
assert(comboGame.combo.tier == 2)
assert(HasEvent(comboEvents, "combo_tier_up") and HasEvent(comboEvents, "combo_shockwave"),
    "tier two perfect parries must create a shockwave event")
assert(FindEvent(comboEvents, "perfect_parry").data.perfectStreak == 3)
PerformPerfectComboParry(3204)
comboEvents = PerformPerfectComboParry(3205)
assert(comboGame.combo.count == ComboConfig.overdriveThreshold)
assert(comboGame.combo.overdriveRemaining == ComboConfig.overdriveDuration)
assert(HasEvent(comboEvents, "overdrive_start"))
local comboHud = Game.GetHud(comboGame).combo
assert(comboHud.count == ComboConfig.overdriveThreshold and comboHud.tier == 3)
assert(comboHud.overdriveRemaining == ComboConfig.overdriveDuration)
assert(comboGame.perfectStreak.count == 5, "perfect streak count must stay independent from combo points")

Game.Update(comboGame, ComboConfig.overdriveDuration + 0.01, 0, 0)
assert(comboGame.combo.overdriveRemaining == 0, "overdrive must expire after its configured duration")
assert(comboGame.perfectStreak.count == 0, "three seconds without a perfect parry must reset the visual streak")
comboGame.player.invulnerabilityTimer = 0
comboGame.projectiles = { Entities.NewProjectile(comboGame.player.x, comboGame.player.y, 0, 0, "enemy", 1) }
Game.Update(comboGame, 0, 0, 0)
assert(comboGame.combo.count == 0 and comboGame.combo.tier == 0,
    "taking damage must reset the active combo")

local hit = Game.New()
Game.StartOrRestart(hit)
Game.ConsumeEvents(hit)
hit.state = "battle"
hit.enemies = { Entities.NewEnemy("soot", { x = 0.5, y = 0.5 }, 3501) }
hit.enemies[1].stateTimer = 99
hit.projectiles = { Entities.NewProjectile(0.5, 0.5, 0, 0, "player", 0.1) }
Game.Update(hit, 0, 0, 0)
events = Game.ConsumeEvents(hit)
assert(HasEvent(events, "projectile_hit"))
assert(FindEvent(events, "projectile_hit").data.damage == 0.1)

local frozen = Game.New()
Game.StartOrRestart(frozen)
Game.ConsumeEvents(frozen)
frozen.state = "battle"
assert(Game.TryParry(frozen))
Game.Update(frozen, 0, 0, 0, PlayerConfig.parryWindow + 0.01)
assert(not Entities.IsParrying(frozen.player), "hit stop must not extend the parry window")

local sharedGauge = Game.New()
Game.StartOrRestart(sharedGauge)
Game.ConsumeEvents(sharedGauge)
sharedGauge.state = "battle"
sharedGauge.enemies = { Entities.NewEnemy("soot", { x = sharedGauge.player.x + 0.12, y = sharedGauge.player.y }, 3551) }
sharedGauge.enemies[1].state = "dash"
sharedGauge.enemies[1].stateTimer = 0.5
assert(Game.TryParry(sharedGauge))
Game.Update(sharedGauge, 0, 0, 0)
assert(sharedGauge.gauge.value == GaugeConfig.perfectGain, "melee parries must fill the shared gauge")
assert(sharedGauge.perfectStreak.count == 1)

sharedGauge.player.parryTimer = 0
sharedGauge.player.parryCooldown = 0
sharedGauge.projectiles = {
    Entities.NewProjectile(sharedGauge.player.x + 0.04, sharedGauge.player.y, -0.1, 0, "enemy", 1, "mushroom"),
}
assert(Game.TryParry(sharedGauge))
sharedGauge.player.parryElapsed = PlayerConfig.perfectParryWindow + 0.01
Game.Update(sharedGauge, 0, 0, 0)
assert(sharedGauge.gauge.value == GaugeConfig.perfectGain + GaugeConfig.normalGain,
    "ranged reflections must continue filling the same gauge")
assert(sharedGauge.perfectStreak.count == 0, "a normal parry must break the strict perfect streak")

local gauge = Game.New()
Game.StartOrRestart(gauge)
Game.ConsumeEvents(gauge)
gauge.state = "battle"
assert(gauge.gauge ~= nil and gauge.gauges == nil, "the game must expose exactly one gauge")
gauge.gauge.value = gauge.gauge.threshold - GaugeConfig.perfectGain
gauge.enemies = { Entities.NewEnemy("soot", { x = gauge.player.x + 0.12, y = gauge.player.y }, 3601) }
gauge.enemies[1].state = "dash"
gauge.enemies[1].stateTimer = 0.5
assert(Game.TryParry(gauge))
Game.ConsumeEvents(gauge)
Game.Update(gauge, 0, 0, 0)
events = Game.ConsumeEvents(gauge)
assert(HasEvent(events, "gauge_full"))
assert(HasEvent(events, "buff_gain"))
local gaugeFull = FindEvent(events, "gauge_full")
assert(type(gaugeFull.data.buffId) == "string")
assert(gaugeFull.data.kind == nil, "the unified gauge event must not expose the removed per-kind contract")
Game.Update(gauge, 8.0, 0, 0)
assert(HasEvent(Game.ConsumeEvents(gauge), "buff_end"))

local chest = Game.New()
Game.StartOrRestart(chest)
Game.ConsumeEvents(chest)
chest.state = "clear"
chest.roomCleared = true
chest.enemies = {}
chest.chests = { Entities.NewChest(chest.player.x, chest.player.y) }

Game.Update(chest, 0, 0, 0)
assert(chest.chests[1].state == "dropping", "a new chest must begin in its drop animation")
assert(not HasEvent(Game.ConsumeEvents(chest), "chest_open"), "a falling chest must not open immediately")

Game.Update(chest, ChestConfig.dropDuration + ChestConfig.bounceDuration + 0.01, 0, 0)
assert(chest.chests[1].state == "idle", "the chest must become collectible after landing and bouncing")
assert(not HasEvent(Game.ConsumeEvents(chest), "chest_open"), "a landed chest must wait for the player")

chest.player.x, chest.player.y = 0.95, 0.95
Game.Update(chest, ChestConfig.pickupDelay + 0.01, 0, 0)
assert(chest.chests[1].state == "idle", "a landed chest must remain while the player is outside pickup range")
assert(not HasEvent(Game.ConsumeEvents(chest), "chest_open"), "a distant player must not open the chest")

chest.player.x, chest.player.y = chest.chests[1].x, chest.chests[1].y
Game.Update(chest, 0, 0, 0)
assert(chest.chests[1].state == "collecting", "entering pickup range must start collection before opening")
assert(not HasEvent(Game.ConsumeEvents(chest), "chest_open"), "collection must finish before the chest opens")

Game.Update(chest, ChestConfig.collectDuration + 0.01, 0, 0)
assert(chest.state == "chest_select", "the choice screen must appear after collection reaches the player")
assert(HasEvent(Game.ConsumeEvents(chest), "chest_open"))

local regeneration = Game.New()
Game.StartOrRestart(regeneration)
regeneration.state = "clear"
regeneration.roomCleared = true
regeneration.enemies = {}
regeneration.chests = {}
regeneration.player.hp = 1
local vitalityEcho = GaugeConfig.buffs[1]
regeneration.activeBuffs = {
    [vitalityEcho.id] = { definition = vitalityEcho, remaining = vitalityEcho.duration },
}
Game.Update(regeneration, 1.0, 0, 0)
assert(regeneration.player.hp > 1, "生命回响应在持续时间内恢复生命")

local transition = Game.New()
Game.StartOrRestart(transition)
Game.ConsumeEvents(transition)
transition.state = "clear"
transition.roomCleared = true
transition.perfectStreak = { count = 2, timer = ComboConfig.perfectStreakWindow }
transition.player.x = 0.5
transition.player.y = RoomConfig.minY
Game.Update(transition, 0, 0, 0)
assert(HasEvent(Game.ConsumeEvents(transition), "room_transition"))
assert(transition.perfectStreak.count == 0, "crossing a doorway must immediately reset the perfect streak")

local boss = Game.New()
Game.StartOrRestart(boss)
Game.ConsumeEvents(boss)
boss.currentRoomId = "warden"
boss.room = boss.map.rooms.warden
boss.state = "battle"
boss.enemies = { Entities.NewEnemy("boss", { x = boss.player.x + 0.14, y = boss.player.y }, 4001) }
boss.enemies[1].hp = boss.enemies[1].maxHp * BossConfig.phaseThreshold + 0.1
boss.enemies[1].state = "active"
boss.enemies[1].attack = "sweep"
boss.enemies[1].stateTimer = 0.5
boss.enemies[1].facing = "left"
boss.player.facing = "right"
assert(Game.TryParry(boss))
Game.ConsumeEvents(boss)
Game.Update(boss, 0, 0, 0)
events = Game.ConsumeEvents(boss)
assert(HasEvent(events, "boss_phase_changed"))
assert(not HasEvent(events, "boss_defeat") and not HasEvent(events, "victory"))
assert(boss.enemies[1].phase == 2 and not boss.enemies[1].dead)
local bossHud = Game.GetHud(boss).boss
assert(bossHud ~= nil and bossHud.phase == 2 and bossHud.targetName == "诅咒显形")

local clearProjectile = Game.New()
Game.StartOrRestart(clearProjectile)
Game.ConsumeEvents(clearProjectile)
clearProjectile.state = "battle"
clearProjectile.enemies = { Entities.NewEnemy("soot", { x = 0.5, y = 0.5 }, 5001) }
clearProjectile.enemies[1].hp = 0.1
clearProjectile.enemies[1].stateTimer = 99
clearProjectile.projectiles = { Entities.NewProjectile(0.5, 0.5, 0.2, 0, "player", 1) }
clearProjectile.projectiles[1].pierceRemaining = 1
for _, definition in ipairs(CrystalConfig.definitions) do
    clearProjectile.player.crystals[definition.id] = definition.maxStacks
end
Game.Update(clearProjectile, 0, 0, 0)
assert(clearProjectile.state == "clear",
    "piercing projectile should clear the room, state=" .. tostring(clearProjectile.state)
        .. " enemies=" .. tostring(#clearProjectile.enemies))
assert(#clearProjectile.projectiles == 1, "piercing projectile must survive its final hit")
local clearProjectileX = clearProjectile.projectiles[1].x
Game.Update(clearProjectile, 0.1, 0, 0)
assert(clearProjectile.projectiles[1].x > clearProjectileX, "projectile must keep moving after a room is cleared")

local victoryProjectile = Game.New()
Game.StartOrRestart(victoryProjectile)
Game.ConsumeEvents(victoryProjectile)
victoryProjectile.currentRoomId = "warden"
victoryProjectile.room = victoryProjectile.map.rooms.warden
victoryProjectile.state = "battle"
victoryProjectile.enemies = { Entities.NewEnemy("boss", { x = 0.5, y = 0.5 }, 5002) }
victoryProjectile.enemies[1].phase = 2
victoryProjectile.enemies[1].state = "purifying"
victoryProjectile.enemies[1].stateTimer = 0.01
victoryProjectile.projectiles = { Entities.NewProjectile(0.5, 0.5, 0.2, 0, "player", 1) }
victoryProjectile.projectiles[1].pierceRemaining = 1
Game.Update(victoryProjectile, 0.02, 0, 0)
assert(victoryProjectile.state == "victory")
assert(#victoryProjectile.projectiles == 1, "piercing projectile must survive purification victory")
local victoryProjectileX = victoryProjectile.projectiles[1].x
Game.Update(victoryProjectile, 0.1, 0, 0)
assert(victoryProjectile.projectiles[1].x > victoryProjectileX, "projectile must keep moving after victory")

print("PASS test_game_events")
