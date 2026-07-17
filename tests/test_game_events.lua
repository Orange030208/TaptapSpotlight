package.path = "./scripts/?.lua;./scripts/?/init.lua;" .. package.path

local Config = require "Config"
local Entities = require "Entities"
local Game = require "Game"

local function HasEvent(events, name)
    for _, event in ipairs(events) do
        if event.name == name then
            return true
        end
    end
    return false
end

local game = Game.New()
assert(#Game.ConsumeEvents(game) == 0)

Game.StartOrRestart(game)
local events = Game.ConsumeEvents(game)
assert(HasEvent(events, "run_start"))
assert(#Game.ConsumeEvents(game) == 0, "consuming events must clear the queue")

game.state = "battle"
assert(Game.TryParry(game))
events = Game.ConsumeEvents(game)
assert(HasEvent(events, "parry_start"))

game.state = "chest_select"
game.stateBeforeChest = "battle"
game.chestOptions = { Config.Upgrades.definitions[1] }
assert(Game.SelectUpgrade(game, 1))
events = Game.ConsumeEvents(game)
assert(HasEvent(events, "upgrade_select"))

local battle = Game.New()
Game.StartOrRestart(battle)
Game.ConsumeEvents(battle)
Game.Update(battle, Config.Room.introDuration + 0.01, 0, 0)
assert(HasEvent(Game.ConsumeEvents(battle), "battle_start"))

battle.state = "battle"
battle.enemies = { Entities.NewEnemy("ranged", { x = 0.2, y = 0.2 }, 1001) }
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

local parry = Game.New()
Game.StartOrRestart(parry)
Game.ConsumeEvents(parry)
parry.state = "battle"
parry.enemies = { Entities.NewEnemy("melee", { x = parry.player.x + 0.12, y = parry.player.y }, 2001) }
parry.enemies[1].hp = 0.5
parry.enemies[1].state = "dash"
parry.enemies[1].stateTimer = 0.5
assert(Game.TryParry(parry))
Game.ConsumeEvents(parry)
Game.Update(parry, 0, 0, 0)
events = Game.ConsumeEvents(parry)
assert(HasEvent(events, "perfect_parry"))
assert(HasEvent(events, "enemy_defeat"))
assert(HasEvent(events, "room_clear"))

local reflect = Game.New()
Game.StartOrRestart(reflect)
Game.ConsumeEvents(reflect)
reflect.state = "battle"
reflect.enemies = { Entities.NewEnemy("melee", { x = 0.2, y = 0.2 }, 3001) }
reflect.enemies[1].stateTimer = 99
reflect.player.facing = "right"
reflect.projectiles = { Entities.NewProjectile(reflect.player.x + 0.04, reflect.player.y, -0.1, 0, "enemy", 1) }
assert(Game.TryParry(reflect))
reflect.player.parryElapsed = Config.Player.perfectParryWindow + 0.01
Game.ConsumeEvents(reflect)
Game.Update(reflect, 0, 0, 0)
events = Game.ConsumeEvents(reflect)
assert(HasEvent(events, "parry_success"))
assert(HasEvent(events, "projectile_reflect"))

local hit = Game.New()
Game.StartOrRestart(hit)
Game.ConsumeEvents(hit)
hit.state = "battle"
hit.enemies = { Entities.NewEnemy("melee", { x = 0.5, y = 0.5 }, 3501) }
hit.enemies[1].stateTimer = 99
hit.projectiles = { Entities.NewProjectile(0.5, 0.5, 0, 0, "player", 0.1) }
Game.Update(hit, 0, 0, 0)
assert(HasEvent(Game.ConsumeEvents(hit), "projectile_hit"))

local gauge = Game.New()
Game.StartOrRestart(gauge)
Game.ConsumeEvents(gauge)
gauge.state = "battle"
gauge.gauges.melee.value = gauge.gauges.melee.threshold - Config.Gauge.perfectGain
gauge.enemies = { Entities.NewEnemy("melee", { x = gauge.player.x + 0.12, y = gauge.player.y }, 3601) }
gauge.enemies[1].state = "dash"
gauge.enemies[1].stateTimer = 0.5
assert(Game.TryParry(gauge))
Game.ConsumeEvents(gauge)
Game.Update(gauge, 0, 0, 0)
events = Game.ConsumeEvents(gauge)
assert(HasEvent(events, "gauge_full"))
assert(HasEvent(events, "buff_gain"))
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
assert(HasEvent(Game.ConsumeEvents(chest), "chest_open"))

local regeneration = Game.New()
Game.StartOrRestart(regeneration)
regeneration.state = "clear"
regeneration.roomCleared = true
regeneration.enemies = {}
regeneration.chests = {}
regeneration.player.hp = 1
local vitalityEcho = Config.Gauge.buffs[1]
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
transition.player.x = 0.5
transition.player.y = Config.Room.minY
Game.Update(transition, 0, 0, 0)
assert(HasEvent(Game.ConsumeEvents(transition), "room_transition"))

local boss = Game.New()
Game.StartOrRestart(boss)
Game.ConsumeEvents(boss)
boss.currentRoomId = "warden"
boss.room = boss.map.rooms.warden
boss.state = "battle"
boss.enemies = { Entities.NewEnemy("boss", { x = boss.player.x + 0.14, y = boss.player.y }, 4001) }
boss.enemies[1].hp = 0.5
boss.enemies[1].state = "dash"
boss.enemies[1].stateTimer = 0.5
assert(Game.TryParry(boss))
Game.ConsumeEvents(boss)
Game.Update(boss, 0, 0, 0)
events = Game.ConsumeEvents(boss)
assert(HasEvent(events, "boss_defeat"))
assert(HasEvent(events, "victory"))

print("PASS test_game_events")
