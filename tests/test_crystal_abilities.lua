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
assert(HasEvent(Game.ConsumeEvents(lightningGame), "crystal_lightning"))

local orbitGame = Game.New()
Grant(orbitGame, "orbit_shards")
CrystalAbilities.OnPerfectParry(orbitGame)
CrystalAbilities.Update(orbitGame, 0.016, 0, 0)
assert(#orbitGame.crystalState.orbitShards == 1, "perfect parry must create an orbit shard")
assert(orbitGame.crystalState.orbitShards[1].x ~= nil, "orbit shards must receive world positions")

local novaGame = Game.New()
Grant(novaGame, "nova_core")
local novaEnemy = Entities.NewEnemy("soot", { x = novaGame.player.x + 0.1, y = novaGame.player.y }, 2)
novaGame.enemies = { novaEnemy }
CrystalAbilities.OnOverdrive(novaGame)
assert(novaEnemy.hp < novaEnemy.maxHp, "overdrive nova must damage nearby enemies")
assert(HasEvent(Game.ConsumeEvents(novaGame), "crystal_nova"))

local timeGame = Game.New()
Grant(timeGame, "time_heart")
timeGame.player.hp = 1
timeGame.projectiles = { Entities.NewProjectile(0.5, 0.5, 0, 0, "enemy", 1) }
assert(CrystalAbilities.TryPreventLethalDamage(timeGame, 1), "time heart must stop the first lethal hit")
assert(timeGame.player.hp == 1 and #timeGame.projectiles == 0)
assert(not CrystalAbilities.TryPreventLethalDamage(timeGame, 1), "time heart must be single-use")

print("PASS test_crystal_abilities")
