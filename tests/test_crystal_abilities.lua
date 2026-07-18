package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local CrystalAbilities = require "CrystalAbilities"
local CrystalConfig = require "Data.CrystalConfig"
local Entities = require "Entities"
local Game = require "Game"

local function FindCrystal(id)
    for _, definition in ipairs(CrystalConfig.definitions) do
        if definition.id == id then return definition end
    end
    error("missing crystal " .. id)
end

local function Grant(game, id)
    assert(Entities.ApplyCrystal(game.player, FindCrystal(id)))
end

local function HasEvent(events, name)
    for _, event in ipairs(events) do
        if event.name == name then return true end
    end
    return false
end

local dashGame = Game.New()
Grant(dashGame, "prism_dash")
dashGame.state = "battle"
CrystalAbilities.OnPerfectParry(dashGame)
assert(dashGame.crystalState.dashWindow > 0, "perfect parry must open the prism dash window")
CrystalAbilities.Update(dashGame, 0.02, 1, 0)
assert(CrystalAbilities.IsDashing(dashGame), "directional movement must activate prism dash")
assert(HasEvent(Game.ConsumeEvents(dashGame), "crystal_dash_start"))

local splitGame = Game.New()
Grant(splitGame, "mirror_split")
local reflected = Entities.NewProjectile(0.5, 0.5, 1, 0, "player", 2, "test")
splitGame.projectiles = { reflected }
CrystalAbilities.OnProjectileReflected(splitGame, reflected, true)
assert(#splitGame.projectiles == 3, "perfect mirror split must create two additional crystal projectiles")
assert(splitGame.projectiles[2].crystalSplit and splitGame.projectiles[3].crystalSplit)

local lightningGame = Game.New()
Grant(lightningGame, "thunder_chime")
lightningGame.player.x, lightningGame.player.y = 0.5, 0.5
local lightningEnemy = Entities.NewEnemy("soot", { x = 0.62, y = 0.5 }, 1)
lightningEnemy.stateTimer = 99
lightningGame.enemies = { lightningEnemy }
CrystalAbilities.OnPerfectParry(lightningGame)
CrystalAbilities.OnPerfectParry(lightningGame)
assert(lightningEnemy.hp < lightningEnemy.maxHp, "two perfect parries must trigger lightning damage")
local lightningEvents = Game.ConsumeEvents(lightningGame)
assert(HasEvent(lightningEvents, "crystal_lightning"))
assert(HasEvent(lightningEvents, "damage_dealt"), "lightning damage must create a popup event")

local orbitGame = Game.New()
Grant(orbitGame, "orbit_shards")
CrystalAbilities.OnPerfectParry(orbitGame)
CrystalAbilities.Update(orbitGame, 0.016, 0, 0)
assert(#orbitGame.crystalState.orbitShards == 1, "perfect parry must create an orbit shard")
assert(orbitGame.crystalState.orbitShards[1].x ~= nil, "orbit shards must receive world positions")

local followGame = Game.New()
Grant(followGame, "orbit_shards")
CrystalAbilities.OnPerfectParry(followGame)
followGame.state = "clear"
local initialShardX = followGame.crystalState.orbitShards[1].x or followGame.player.x
Game.Update(followGame, 0.1, 1, 0)
local followingShard = followGame.crystalState.orbitShards[1]
assert(followingShard ~= nil and followingShard.x > initialShardX,
    "orbit shards must follow the player after a room has been cleared")
followingShard.remaining = 0.05
CrystalAbilities.UpdatePassive(followGame, 0.06)
assert(#followGame.crystalState.orbitShards == 0, "each orbit shard must expire independently")
assert(HasEvent(Game.ConsumeEvents(followGame), "crystal_orbit_expire"))

local projectileGuardGame = Game.New()
Grant(projectileGuardGame, "orbit_shards")
CrystalAbilities.OnPerfectParry(projectileGuardGame)
CrystalAbilities.UpdatePassive(projectileGuardGame, 0)
local projectileGuard = projectileGuardGame.crystalState.orbitShards[1]
projectileGuardGame.projectiles = {
    Entities.NewProjectile(projectileGuard.x, projectileGuard.y, 0.3, 0, "enemy", 1, "mushroom"),
}
CrystalAbilities.ResolveOrbitGuards(projectileGuardGame)
assert(#projectileGuardGame.crystalState.orbitShards == 0, "a blocked projectile must consume one orbit shard")
assert(projectileGuardGame.projectiles[1].owner == "player" and projectileGuardGame.projectiles[1].damage == 0.1,
    "orbit-reflected projectiles must deal only symbolic damage")
assert(HasEvent(Game.ConsumeEvents(projectileGuardGame), "crystal_orbit_block"))

local meleeGuardGame = Game.New()
Grant(meleeGuardGame, "orbit_shards")
CrystalAbilities.OnPerfectParry(meleeGuardGame)
CrystalAbilities.UpdatePassive(meleeGuardGame, 0)
local meleeGuard = meleeGuardGame.crystalState.orbitShards[1]
local dashEnemy = Entities.NewEnemy("soot", { x = meleeGuard.x, y = meleeGuard.y }, 3)
dashEnemy.state, dashEnemy.stateTimer, dashEnemy.attackSerial = "dash", 0.4, 1
meleeGuardGame.enemies = { dashEnemy }
CrystalAbilities.ResolveOrbitGuards(meleeGuardGame)
assert(#meleeGuardGame.crystalState.orbitShards == 0, "a blocked melee attack must consume one orbit shard")
assert(dashEnemy.state == "recovery" and dashEnemy.hp == dashEnemy.maxHp - 0.1,
    "orbit guard must cancel a dash while dealing minimal parry damage")

local exclusionGame = Game.New()
Grant(exclusionGame, "orbit_shards")
CrystalAbilities.OnPerfectParry(exclusionGame)
CrystalAbilities.UpdatePassive(exclusionGame, 0)
local exclusionGuard = exclusionGame.crystalState.orbitShards[1]
local boss = Entities.NewEnemy("boss", { x = exclusionGuard.x, y = exclusionGuard.y }, 4)
local moss = Entities.NewEnemy("toxic_moss", { x = exclusionGuard.x, y = exclusionGuard.y }, 5)
assert(not Entities.TryOrbitGuardEnemy(exclusionGuard, boss, exclusionGame.player, 0.1),
    "orbit guard must not affect bosses")
assert(not Entities.TryOrbitGuardEnemy(exclusionGuard, moss, exclusionGame.player, 0.1),
    "orbit guard must not block ground hazards")

local novaGame = Game.New()
Grant(novaGame, "nova_core")
local novaEnemy = Entities.NewEnemy("soot", { x = novaGame.player.x + 0.1, y = novaGame.player.y }, 2)
novaGame.enemies = { novaEnemy }
CrystalAbilities.OnOverdrive(novaGame)
assert(novaEnemy.hp < novaEnemy.maxHp, "overdrive nova must damage nearby enemies")
local novaEvents = Game.ConsumeEvents(novaGame)
assert(HasEvent(novaEvents, "crystal_nova"))
assert(HasEvent(novaEvents, "damage_dealt"), "nova damage must create a popup event")

local timeGame = Game.New()
Grant(timeGame, "time_heart")
timeGame.player.hp = 1
timeGame.projectiles = { Entities.NewProjectile(0.5, 0.5, 0, 0, "enemy", 1) }
assert(CrystalAbilities.TryPreventLethalDamage(timeGame, 1), "time heart must stop the first lethal hit")
assert(timeGame.player.hp == 1 and #timeGame.projectiles == 0)
assert(not CrystalAbilities.TryPreventLethalDamage(timeGame, 1), "time heart must be single-use")

print("PASS test_crystal_abilities")
